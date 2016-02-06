module samurai.GameInfo;
import samurai;

import std.stdio;
import std.string;
import std.array;
import std.conv;
import std.range;
import std.algorithm;
import std.typecons;
import Math = std.math;

alias Point = Tuple!(int, "x", int, "y");

class GameInfo {
  public:
    enum PLAYER_NUM = 6;
    enum TURNS_RULE = [0, 3, 4, 1, 2, 5, 3, 0, 1, 4, 5, 2];
    enum int[3][12] NEXT_AI_TURN_LUT = [
      [2, 1, 1],
      [0, 1, 1],
      [1, 2, 1],
      [1, 0, 1],
      [1, 1, 2],
      [1, 1, 0],
      [2, 1, 1],
      [0, 1, 1],
      [1, 2, 1],
      [1, 0, 1],
      [1, 1, 2],
      [1, 1, 0]
    ];
    int turns;
    int side;
    int weapon;
    int width, height;
    int maxCure;
    SamuraiInfo[PLAYER_NUM] samuraiInfo;
    int turn, curePeriod;
    int[][] field;

    this(GameInfo info) @safe pure {
      this.turns = info.turns;
      this.side = info.side;
      this.weapon = info.weapon;
      this.width = info.width;
      this.height = info.height;
      this.maxCure = info.maxCure;
      this.samuraiInfo = info.samuraiInfo.dup;
      this.turn = info.turn;
      this.curePeriod = info.curePeriod;
//      this.field = info.field.map!(a => a.dup).array;
      this.field = info.field;

      this.occupyCount = info.occupyCount;
      this.playerKill = info.playerKill;
      this.selfCount = info.selfCount;
      this.usurpCount = info.usurpCount;
      this.fightCount = info.fightCount;
      this.groupLevel = info.groupLevel;

      this.paints = info.paints;

      this.probPlaces = info.probPlaces;

      this.isAttackContain = info.isAttackContain;
      this.isKilled = info.isKilled;
    }

    this() {
      string[] res = this.read();

      this.turns   = res[0].to!int;
      this.side    = res[1].to!int;
      this.weapon  = res[2].to!int;
      this.width   = res[3].to!int;
      this.height  = res[4].to!int;
      this.maxCure = res[5].to!int;

      foreach(ref s; this.samuraiInfo) {
        res = this.read();
        s.homeX = res[0].to!int;
        s.homeY = res[1].to!int;
      }
      foreach (ref s; this.samuraiInfo) {
        res = this.read();
        s.rank = res[0].to!int;
        s.score = res[1].to!int;
      }

      this.turn = 0;
      this.curePeriod = 0;
      this.field = new int[][](this.height, this.width);

      this.occupyCount = 0;
      this.playerKill = 0;
      this.selfCount = 0;
      this.usurpCount = 0;
      this.fightCount = 0;
      this.groupLevel = 0;

      this.paints = 0;

      this.isAttackContain = false;
      this.isKilled = false;

      0.writeln;
      stdout.flush;
    }

    void readTurnInfo() {
      string[] res = this.read();

      assert(res.length > 0);

      this.turn = res[0].to!int;

      assert(turn >= 0);

      res = this.read();
      this.curePeriod = res[0].to!int;

      foreach (ref s; this.samuraiInfo)  {
        res = this.read();
        s.curX = res[0].to!int;
        s.curY = res[1].to!int;
        s.hidden = res[2].to!int;
      }

      for (int i = 0; i < this.height; ++i) {
        res = this.read();
        for (int j = 0; j < this.width; ++j) {
          this.field[i][j] = res[j].to!int;
        }
      }
    }

    bool isValid(int action) const pure nothrow @safe {
      immutable me = this.samuraiInfo[this.weapon];
      int x = me.curX;
      int y = me.curY;

      switch (action) {
        case 1,2,3,4:
          return me.hidden == 0;
        case 5,6,7,8: {
          final switch(action) {
            case 5: ++y; break;
            case 6: ++x; break;
            case 7: --y; break;
            case 8: --x; break;
          }
          assert (x != me.curX || y != me.curY);
          if (x < 0 || this.width <= x
              || y < 0 || this.height <= y) {
            return false;
          }
          if (me.hidden == 1 && this.field[y][x] >= 3) {
            return false;
          }
          foreach (i, s; this.samuraiInfo) {
            if ( i == this.weapon ) {
              continue;
            }
            if ( x == s.curX && y == s.curY ) {
              return false;
            }
            if ( x == s.homeX && y == s.homeY ) {
              return false;
            }
          }
          return true;
        }
        case 9: {
          if (me.hidden == 1) {
            return false;
          }
          if (this.field[y][x] >= 3) {
            return false;
          }
          return true;
        }
        case 10: {
          if (me.hidden != 1) {
            return false;
          }
          foreach (s; this.samuraiInfo) {
            if (s.hidden != 1 && s.curX == x && s.curY == y) {
              return false;
            }
          }
          return true;
        }
        default:
          return action == 0;
      }
    }

    static auto rotate(int dir, int x, int y) pure nothrow @safe {
      final switch (dir) {
        case 0:
          return Point(x, y);
        case 1:
          return Point(y, -x);
        case 2:
          return Point(-x, -y);
        case 3:
          return Point(-y, x);
      }
    }

    void occupy(int dir) pure @safe {
      const fieldDup = this.field;
      this.field = this.field.map!(a => a.dup).array;

      occupyCount = 0;
      playerKill = 0;
      selfCount = 0;
      usurpCount = 0;
      fightCount = 0;
      isKilled = false;
      int groupCount = 0;

      isAttackContain |= true;

      immutable me = this.samuraiInfo[this.weapon];
      immutable int curX = me.curX;
      immutable int curY = me.curY;

      enum size = [4, 5, 7];
      enum ox = [
        [0, 0, 0, 0],
        [0, 0, 1, 1, 2],
        [-1, -1, -1, 0, 1, 1, 1]
      ];
      enum oy = [
        [1, 2, 3, 4],
        [1, 2, 0, 1, 0],
        [0, -1, 1, 1, 1, -1, 0]
      ];
      for (int i = 0; i < size[this.weapon]; ++i) {
        auto pos = GameInfo.rotate(dir, ox[this.weapon][i], oy[this.weapon][i]);
        int nx = curX + pos.x;
        int ny = curY + pos.y;
        if (0<=nx && nx<width && 0<=ny && ny<height) {
          bool isHome = false;
          foreach (s; this.samuraiInfo) {
            isHome |= s.homeX == nx && s.homeY == ny;
          }
          if (!isHome) {
            if (this.field[ny][nx] != this.weapon) {
              if (this.field[ny][nx] >= 3) {
                if (this.field[ny][nx] < 6) {
                  ++usurpCount;
                }
                if (this.field[ny][nx] >= 8) {
                  ++occupyCount;
                }
              } else {
                ++selfCount;
              }
              if (this.field[ny][nx] < 6) {
                int[2] scores;
                for (int s = 0; s < 2; ++s) {
                  for (int j = 0; j < 3; ++j) {
                    scores[s] += this.paints[j + s * 3];
                  }
                }
                int rem = this.width * this.height - (scores[0] + scores[1]);
                scores[1] += rem;
                if (scores[0] * 2 > scores[1] * 3
                    && (this.samuraiInfo[field[ny][nx]].score >= this.samuraiInfo[this.weapon].score
                      || this.paints[this.field[ny][nx]] >= this.paints[this.weapon])
                    ) {
                  ++fightCount;
                }
              }
              this.field[ny][nx] = this.weapon;

              enum ofs = [
                [0, 1],
                [0, -1],
                [1, 0],
                [-1, 0]
              ];
              foreach (dp; ofs) {
                int adjx = nx + dp[0];
                int adjy = ny + dp[1];
                if ( adjx < 0 || this.width <= adjx || adjy < 0 || this.height <= adjy ) {
                  ++groupCount;
                  break;
                }
                if (fieldDup[adjy][adjx] == this.weapon) {
                  ++groupCount;
                  break;
                }
              }
            }
            for (int j = 3; j < GameInfo.PLAYER_NUM; ++j) {
              SamuraiInfo si = this.samuraiInfo[j];
              if (si.curX == nx && si.curY == ny) {
                si.curX = si.homeX;
                si.curY = si.homeY;
                si.hidden = 0;
                this.samuraiInfo[j] = si;
                ++playerKill;
                isKilled[j - 3] |= true;
              }
            }
          }
        }
      }

      groupLevel = cast(double) groupCount / size[this.weapon];
    }

    void doAction(int action) pure @safe {
      assert (isValid(action));
      auto me = this.samuraiInfo[this.weapon];
      int curX = me.curX;
      int curY = me.curY;

      final switch(action) {
        case 1, 2, 3, 4:
          this.occupy(action - 1);
          break;
        case 5: ++curY; break;
        case 6: ++curX; break;
        case 7: --curY; break;
        case 8: --curX; break;
        case 9:
          me.hidden = 1;
          break;
        case 10:
          me.hidden = 0;
          break;
      }
      me.curX = curX;
      me.curY = curY;
      this.samuraiInfo[this.weapon] = me;
    }

    double score(const Merits m) const pure nothrow @safe {
      return this.samuraiInfo[this.weapon].hidden * m.hide
          + this.selfCount * m.self
          + this.playerKill * m.kill
          + this.occupyCount * m.terr
          + this.usurpCount * m.usur
          + this.fightCount * m.fght
          + this.groupLevel * m.grup
          + this.safeLevel() * m.safe
          + this.deployLevel() * m.depl
          + this.centerLevel() * m.midd
          + this.hasKilledRivalAtNextTurn() * m.krnt;
    }

    deprecated
    bool isSafe() const pure nothrow @safe {
      bool flag = true;
      SamuraiInfo me = this.samuraiInfo[this.weapon];
      // 3
      {
        SamuraiInfo si = this.samuraiInfo[3];
        if (si.curX != -1 && si.curY != -1) {
          int dx = Math.abs(si.curX - me.curX);
          int dy = Math.abs(si.curY - me.curY);
          flag &= (dx + dy > 5 || min(dx, dy) >= 2);
        }
      }
      // 4
      {
        SamuraiInfo si = this.samuraiInfo[4];
        if (si.curX != -1 && si.curY != -1) {
          int dx = Math.abs(si.curX - me.curX);
          int dy = Math.abs(si.curY - me.curY);
          flag &= dx + dy > 3;
        }
      }
      // 5
      {
        SamuraiInfo si = this.samuraiInfo[5];
        if (si.curX != -1 && si.curY != -1) {
          int dx = Math.abs(si.curX - me.curX);
          int dy = Math.abs(si.curY - me.curY);
          flag &= dx + dy > 3 || max(dx, dy) > 2;
        }
      }
      return flag;
    }
    static bool isSafe(immutable Point me, immutable Point rv, immutable int idx) pure nothrow @safe {
      immutable int dx = Math.abs(rv.x - me.x);
      immutable int dy = Math.abs(rv.y - me.y);
      final switch (idx) {
        case 3:
          return (dx + dy > 5 || min(dx, dy) >= 2);
        case 4:
          return dx + dy > 3;
        case 5:
          return dx + dy > 3 || max(dx, dy) > 2;
      }
    }
    static bool isSafeW2T(immutable Point me, immutable Point rv, immutable int idx) pure nothrow @safe {
      immutable int dx = Math.abs(rv.x - me.x);
      immutable int dy = Math.abs(rv.y - me.y);
      final switch (idx) {
        case 3:
          return (dx + dy) >= 9;
        case 4:
          return (dx + dy) >= 7;
        case 5:
          return (dx + dy) >= 7 || max(dx, dy) >= 6;
      }
    }
    static bool isSafeW2A(immutable Point me, immutable Point rv, immutable int idx) pure nothrow @safe {
      immutable int dx = Math.abs(rv.x - me.x);
      immutable int dy = Math.abs(rv.y - me.y);
      final switch (idx) {
        case 3:
          return (dx + dy) >= 7 || min(dx, dy) >= 3;
        case 4:
          return (dx + dy) >= 5;
        case 5:
          return (dx + dy) >= 5 || max(dx, dy) >= 4;
      }
    }
    static bool isSafeLimit(immutable Point me, immutable Point rv, immutable int idx) pure nothrow @safe {
      immutable int dx = Math.abs(rv.x - me.x);
      immutable int dy = Math.abs(rv.y - me.y);
      final switch(idx) {
        case 3:
          return (dx + dy) == 6 || min(dx, dy) == 2;
        case 4:
          return (dx + dy) == 4;
        case 5:
          return (dx + dy) == 4 || max(dx, dy) == 3;
      }
    }
    deprecated
    bool isSafe(immutable int idx, immutable Point p) const pure nothrow @safe {
      const SamuraiInfo me = this.samuraiInfo[this.weapon];
      return GameInfo.isSafe(Point(me.curX, me.curY), p, idx);
    }
    bool isSafe2(immutable int idx, immutable Point rvp) const pure nothrow @safe {
      const SamuraiInfo me = this.samuraiInfo[this.weapon];
      immutable mep = Point(me.curX, me.curY);
      immutable int[3] turns = nextAITurn2();
      final switch (turns[idx - 3]) {
        case 0:
          return true;
        case 1:
          return isSafe(mep, rvp, idx);
        case 2:
          if (isKilled[idx - 3]) {
            return true;
          } else {
            /+ TIMED OUT
            enum large_ofs = [
                                            [0, -3],
                                  [-1, -2], [0, -2], [1, -2],
                        [-2, -1], [-1, -1], [0, -1], [1, -1], [2, -1],
              [-3,  0], [-2,  0], [-1,  0], [0,  0], [1,  0], [2,  0], [3, 0],
                        [-2,  1], [-1,  1], [0,  1], [1,  1], [2,  1],
                                  [-1,  2], [0,  2], [1,  2],
                                            [0,  3]
            ];
            bool is_absolute_safe = true;
            foreach (dp; large_ofs) {
              if (!is_absolute_safe) {
                break;
              }
              Point np = Point(p.x + dp[0], p.y + dp[1]);
              if (np.x < 0 || this.width <= np.x || np.y < 0 || this.height <= np.y) {
                continue;
              }
              is_absolute_safe &= isSafe(idx, np);
            }
            if (is_absolute_safe) {
              return true;
            }
            +/
            /+
            if (isSafeW2T(mep, rvp, idx)) {
              return true;
            }
            if (isSafeW2A(mep, rvp, idx)) {
              return true;
            }
            +/
            return isSafeW2T(mep, rvp, idx)
                || (!isAttackContain && me.hidden && isSafeW2A(mep, rvp, idx));
            /+ TIMED OUT
            enum ofs = [
              [0, 1],
              [0, -1],
              [1, 0],
              [-1, 0]
            ];
            bool res = isSafe(mep, rvp, idx) && !isAttackContain && me.hidden;
            foreach (dp; ofs) {
              if (!res) {
                break;
              }
              Point np = Point(rvp.x + dp[0], rvp.y + dp[1]);
              if (np.x < 0 || this.width <= np.x || np.y < 0 || this.height <= np.y) {
                continue;
              }
              res &= isSafe(mep, np, idx);
            }
            return res;
            +/
          }
      }
    }

    double safeLevel() const pure nothrow @safe {
      double safe = 1.0;
      for (int i = 3; i < 6; ++i) {
        SamuraiInfo si = this.samuraiInfo[i];
        immutable Point p = Point(si.curX, si.curY);
        if (p.x != -1 && p.y != -1) {
          safe = min(safe, isSafe2(i, p) ? 1.0 : 0.0);
        } else {
          immutable Point rh = Point(si.homeX, si.homeY);
          ulong sum = probPlaces[i].length;
          ulong cnt = 0;
          if (probPlaces[i].find(rh).empty) {
            ++sum;
            if (isSafe2(i, rh)) {
              ++cnt;
            }
          }
          assert (sum > 0);
          foreach (q; probPlaces[i]) {
            if (isSafe2(i, q)) {
              ++cnt;
            }
          }
          assert (cnt <= sum);
          safe = min(safe, ((cast(double)cnt / sum) * 0.25 + 0.75));
        }
      }
      return safe;
    }

    double deployLevel() const pure nothrow @safe {
      const SamuraiInfo me = this.samuraiInfo[this.weapon];
      double res = 1 << 28;
      for (int i = 0; i < 3; ++i) {
        if (this.weapon == i) continue;
        SamuraiInfo si = this.samuraiInfo[i];
        res = min(res, Math.abs((me.curX - si.curX) + Math.abs(me.curY - si.curY)));
      }
      return res;
    }
    double centerLevel() const pure nothrow @safe {
      const SamuraiInfo me = this.samuraiInfo[this.weapon];
      double dist = Math.abs(me.curX - this.width / 2) + Math.abs(me.curY - this.height / 2);
      double maxd = this.width / 2 + this.height / 2;
      return maxd - dist;
    }
    bool hasKilledRivalAtNextTurn() const pure nothrow @safe {
      immutable int[3] turns = nextAITurn2();
      return isKilled[this.weapon] && turns[this.weapon] == 0;
    }
    bool hasHiddenTactically() const pure nothrow @safe {
      const SamuraiInfo me = this.samuraiInfo[this.weapon];
      if (isAttackContain || !me.hidden) {
        return false;
      }
      immutable mep = Point(me.curX, me.curY);
      immutable int[3] turns = nextAITurn2();
      bool flag = false;
      for (int i = 3; i < 6; ++i) {
        const SamuraiInfo si = this.samuraiInfo[i];
        immutable sip = Point(si.curX, si.curY);
        if (sip.x == -1 && sip.y == -1) {
          continue;
        }
        if (turns[i - 3] != 1) {
          continue;
        }
        flag |= isSafeLimit(mep, sip, i);
      }
      return flag;
    }

    void setRivalInfo(int[6] paints) pure nothrow @safe {
      this.paints = paints;
    }

    void setProbPlaces(int idx, bool[Point] set) {
      this.probPlaces[idx] = [];
      foreach (p; set.byKey) {
        this.probPlaces[idx] ~= p;
      }
    }

    deprecated
    int[3] nextAITurn() const pure @safe nothrow {
      int id = this.side * 3 + this.weapon;
      assert (TURNS_RULE[this.turn % 12] == id);
      int[6] cnt = 0;
      for (int i = 1; i <= 12; ++i) {
        int jd = TURNS_RULE[(this.turn + i) % 12];
        if (jd == id) {
          break;
        }
        ++cnt[jd];
      }
      int[3] res;
      for (int i = 0; i < 3; ++i) {
        res[i] = cnt[i + (1 - this.side) * 3];
      }
      assert (res == NEXT_AI_TURN_LUT[this.turn % 12]);
      return res;
    }
    int[3] nextAITurn2() const pure @safe nothrow {
      return NEXT_AI_TURN_LUT[this.turn % 12];
    }
 private:
    int occupyCount;
    int playerKill;
    int selfCount;
    int usurpCount;
    int fightCount;
    double groupLevel;
    int[6] paints;
    Point[][6] probPlaces;
    bool isAttackContain;
    bool[3] isKilled;

    string[] read() {
      string line = "";
      do {
        line = readln.strip;
      } while (line.length > 0 && line[0] == '#');
      return line.split(" ");
    }
}


