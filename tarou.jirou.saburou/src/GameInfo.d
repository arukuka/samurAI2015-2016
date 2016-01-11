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
    int turns;
    int side;
    int weapon;
    int width, height;
    int maxCure;
    SamuraiInfo[] samuraiInfo;
    int turn, curePeriod;
    int[][] field;

    this(const GameInfo info) {
      this.turns = info.turns;
      this.side = info.side;
      this.weapon = info.weapon;
      this.width = info.width;
      this.height = info.height;
      this.maxCure = info.maxCure;
      this.samuraiInfo = info.samuraiInfo.dup;
      this.turn = info.turn;
      this.curePeriod = info.curePeriod;
      this.field = info.field.map!(a => a.dup).array;

      this.occupyCount = info.occupyCount;
      this.playerKill = info.playerKill;
      this.selfCount = info.selfCount;
      this.usurpCount = info.usurpCount;
    }

    this() {
      string[] res = this.read();

      this.turns   = res[0].to!int;
      this.side    = res[1].to!int;
      this.weapon  = res[2].to!int;
      this.width   = res[3].to!int;
      this.height  = res[4].to!int;
      this.maxCure = res[5].to!int;
      this.samuraiInfo = PLAYER_NUM.iota
          .map!(i => SamuraiInfo())
          .map!((s){
            res = this.read();
            s.homeX = res[0].to!int;
            s.homeY = res[1].to!int;
            return s;
          })
          .map!((s){
            res = this.read();
            s.rank = res[0].to!int;
            s.score = res[1].to!int;
            return s;
          })
          .array;
      this.turn = 0;
      this.curePeriod = 0;
      this.field = new int[][](this.height, this.width);

      this.occupyCount = 0;
      this.playerKill = 0;
      this.selfCount = 0;
      this.usurpCount = 0;

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

    bool isValid(int action) const pure @safe {
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
          if (!this.samuraiInfo.map!((s) {
            if ( s == me ) {
              return true;
            }
            if ( x == s.curX && y == s.curY ) {
              return false;
            }
            if ( x == s.homeX && y == s.homeY ) {
              return false;
            }
            return true;
          }).reduce!((a, b) => a && b)) {
            return false;
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
      this.field = this.field.map!(a => a.dup).array;
      this.occupyCount = this.playerKill = this.selfCount = this.usurpCount = 0;

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
          bool isHome = this.samuraiInfo
              .map!(s => s.homeX == nx && s.homeY == ny)
              .reduce!((l, r) => l || r);
          if (!isHome) {
            if (this.field[ny][nx] != this.weapon) {
              if (this.field[ny][nx] >= 3) {
                if (this.field[ny][nx] < 6) {
                  ++usurpCount;
                }
                ++occupyCount;
              }
              ++selfCount;
              this.field[ny][nx] = this.weapon;
            }
            for (int j = 3; j < GameInfo.PLAYER_NUM; ++j) {
              SamuraiInfo si = this.samuraiInfo[j];
              if (si.curX == nx && si.curY == ny) {
                si.curX = si.homeX;
                si.curY = si.homeY;
                si.hidden = 0;
                this.samuraiInfo[j] = si;
                ++playerKill;
              }
            }
          }
        }
      }
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

    double score(immutable Merits m) const pure nothrow @safe @nogc {
      return this.samuraiInfo[this.weapon].hidden * m.hide
          + this.selfCount * m.self
          + this.playerKill * m.kill
          + this.occupyCount * m.terr
          + this.usurpCount * m.usur
          + this.isSafe() * m.safe
          + this.deployLevel() * m.depl
          + this.centerLevel() * m.midd;
    }

    bool isSafe() const pure nothrow @safe @nogc {
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
    double deployLevel() const pure nothrow @safe @nogc {
      SamuraiInfo me = this.samuraiInfo[this.weapon];
      double res = 1 << 28;
      for (int i = 0; i < 3; ++i) {
        if (this.weapon == i) continue;
        SamuraiInfo si = this.samuraiInfo[i];
        res = min(res, Math.abs((me.curX - si.curX) + Math.abs(me.curY - si.curY)));
      }
      return res;
    }
    double centerLevel() const pure nothrow @safe @nogc {
      SamuraiInfo me = this.samuraiInfo[this.weapon];
      double dist = Math.abs(me.curX - this.width / 2) + Math.abs(me.curY - this.height / 2);
      double maxd = this.width / 2 + this.height / 2;
      return maxd - dist;
    }

  private:
    int occupyCount;
    int playerKill;
    int selfCount;
    int usurpCount;

    string[] read() {
      string line = "";
      do {
        line = readln.strip;
      } while (line.length > 0 && line[0] == '#');
      return line.split(" ");
    }
}

