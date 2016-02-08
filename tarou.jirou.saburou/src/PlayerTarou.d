module samurai.PlayerTarou;
import samurai;

import std.stdio;
import std.random;
import std.algorithm;
import std.range;
import std.array;
import std.conv;
import std.typecons;
import std.format;

class PlayerTarou : Player {
  private:
    enum COST = [0, 4, 4, 4, 4, 2, 2, 2, 2, 1, 1];
    enum MAX_POWER = 7;

    int[][] latestField = null;
    int[][] fieldDup = null;
    SamuraiInfo[] samuraiDup = null;
    Point[][6] probPointDup;
    Point rivalPointDup;
    bool rivalPointDupFlag = false;

    static const Merits DEFAULT_MERITS = new Merits.MeritsBuilder()
        .setTerr(25)
        .setSelf(3)
        .setKill(125)
        .setHide(0)
        .setSafe(200)
        .setUsur(20)
        .setDepl(1)
        .setMidd(1)
        .setFght(5)
        .build();
    static const Merits SPEAR_MERITS = new Merits.MeritsBuilder()
        .setTerr(25)
        .setSelf(3)
        .setKill(125)
        .setHide(0)
        .setSafe(200)
        .setUsur(20)
        .setDepl(1)
        .setMidd(1)
        .setFght(5)
        .setGrup(3)
        .setTchd(100)
        .build();
    static const Merits SWORD_MERITS = new Merits.MeritsBuilder()
        .setTerr(25)
        .setSelf(3)
        .setKill(125)
        .setHide(0)
        .setSafe(200)
        .setUsur(20)
        .setDepl(1)
        .setMidd(1)
        .setFght(5)
        .setTchd(100)
        .build();
    static const Merits BATTLEAX_MERITS = new Merits.MeritsBuilder()
        .setTerr(25)
        .setSelf(3)
        .setKill(125)
        .setHide(0)
        .setSafe(200)
        .setUsur(20)
        .setDepl(1)
        .setMidd(1)
        .setFght(5)
        .setGrup(3)
        .setTchd(100)
        .build();
    static const Merits[3] MERITS4WEAPON = [
      SPEAR_MERITS,
      SWORD_MERITS,
      BATTLEAX_MERITS
    ];

    static const Merits NEXT_DEFAULT_MERITS = new Merits.MeritsBuilder()
        .setTerr(25)
        .setSelf(3)
        .setKill(0)
        .setHide(0)
        .setSafe(0)
        .setUsur(20)
        .setDepl(1)
        .setMidd(1)
        .setFght(5)
        .build();
    static const Merits NEXT_SPEAR_MERITS = new Merits.MeritsBuilder()
        .setTerr(25)
        .setSelf(3)
        .setUsur(20)
        .setDepl(1)
        .setMidd(1)
        .setFght(5)
        .setGrup(3)
        .setKrnt(125)
        .build();
    static const Merits NEXT_SWORD_MERITS = new Merits.MeritsBuilder()
        .setTerr(25)
        .setSelf(3)
        .setUsur(20)
        .setDepl(1)
        .setMidd(1)
        .setFght(5)
        .setKrnt(125)
        .build();
    static const Merits NEXT_BATTLEAX_MERITS = new Merits.MeritsBuilder()
        .setTerr(25)
        .setSelf(3)
        .setUsur(20)
        .setDepl(1)
        .setMidd(1)
        .setFght(5)
        .setGrup(3)
        .setKrnt(125)
        .build();
    static const Merits[3] NEXT_MERITS4WEAPON = [
      NEXT_SPEAR_MERITS,
      NEXT_SWORD_MERITS,
      NEXT_BATTLEAX_MERITS
    ];

    static class HistoryTree {
      private:
        GameInfo info;
        HistoryTree[] children;
        HistoryTree parent;
        int action;

        int[] getActions(int[] actions) @safe const pure nothrow {
          if (parent !is null) {
            actions = action ~ actions;
            return parent.getActions(actions);
          } else {
            return actions;
          }
        }

      public:
        this(HistoryTree parent, GameInfo info, int action) @safe pure {
          this.parent = parent;
          this.info = info;
          this.action = action;
        }
        GameInfo getInfo() @safe pure nothrow { return info; }

        void add(HistoryTree c) @safe pure nothrow { children ~= c; }

        int[] getActions() @safe const pure nothrow {
          return getActions([]);
        }

        HistoryTree[] collect() @safe pure nothrow {
          HistoryTree[] list;
          if (children.length > 0) {
            foreach (c; children) {
              list ~= c.collect();
            }
          }
          list ~= this;
          return list;
        }
    }

    deprecated
    void plan(HistoryTree tree, immutable int power) {
      for (int i = 1; i < COST.length; ++i) {
        if (COST[i] <= power && tree.getInfo().isValid(i)) {
          GameInfo next = new GameInfo(tree.getInfo());
          next.doAction(i);
          HistoryTree child = new HistoryTree(tree, next, i);
          tree.add(child);
          plan(child, power - COST[i]);
        }
      }
    }
    struct Node {
      int cost;
      int attack;
      HistoryTree tree;

      string toString() @safe const pure {
        return format("{%d, %b, %b, [%(%d %)]}", cost, attack, tree.getActions());
      }

      bool opEquals(ref const typeof(this) r) const @safe pure nothrow {
        return tree.getActions() == r.tree.getActions();
      }

      Node dup() @safe pure nothrow {
        Node res = {
          cost,
          attack,
          tree
        };
        return res;
      }
    }

    void plan2(HistoryTree root) @trusted
    {
      auto queue = redBlackTree!((l, r) => l.cost > r.cost, true, Node)();
      Node atom = {
        MAX_POWER,
        0,
        root
      };
      queue.insert(atom);
      debug {
        stderr.writeln("-- plan2 --");
        stderr.writeln = root.getActions();
      }
      // attack, hidden, height, width : power
      int[5][2][20][20] done;
      for (int x = 0; x < 20; ++x) {
        for (int y = 0; y < 20; ++y) {
          for (int i = 0; i < 2; ++i) {
            for (int j = 0; j < 5; ++j) {
              done[x][y][i][j] = -1;
            }
          }
        }
      }
      auto me = root.info.samuraiInfo[root.info.weapon];
      done[me.curX][me.curY][me.hidden][0] = MAX_POWER;
      while (queue.length) {
        Node node = queue.front();
        queue.removeFront();
        debug {
          stderr.writeln("\t", node.cost, node.tree.getActions());
        }

        for (int i = 1; i < COST.length; ++i) {
          if (COST[i] <= node.cost && node.tree.getInfo().isValid(i)) {
            GameInfo next = new GameInfo(node.tree.getInfo());
            next.doAction(i);
            auto nme = next.samuraiInfo[next.weapon];
            if (node.cost - COST[i]
                <= done[nme.curX][nme.curY]
                    [nme.hidden]
                    [node.attack | ((1 <= i && i <= 4) ? i : 0)]
                ) {
              continue;
            }

            debug {
              stderr.writeln("\t\t", i, " -> ", node.cost - COST[i]);
            }

            done[nme.curX][nme.curY]
                    [nme.hidden]
                    [node.attack | ((1 <= i && i <= 4) ? i : 0)]
                = node.cost - COST[i];

            HistoryTree child = new HistoryTree(node.tree, next, i);
            node.tree.add(child);
            Node nnode = {
              node.cost - COST[i],
              node.attack | ((1 <= i && i <= 4) ? i : 0),
              child
            };

            queue.insert(nnode);
          }
        }
      }
    }

  public:
    void setDup(in GameInfo info) pure @safe {
      fieldDup = info.field.map!(a => a.dup).array;
      samuraiDup = info.samuraiInfo.dup;
    }
    override void play(GameInfo info) @trusted {
      debug {
        stderr.writeln("turn : ", info.turn, ", side : ", info.side, ", weapon : ", info.weapon);
      }

      if (rivalPointDupFlag) {
        auto rival = info.samuraiInfo[info.weapon + 3];
        if (rival.curX == -1 && rival.curY == -1) {
          if (rivalPointDup.x != -1 && rivalPointDup.y != -1
              && info.field[rivalPointDup.y][rivalPointDup.x] >= 3) {
            debug(2) {
              stderr.writeln("\tknew it : (", rivalPointDup.x, ", ", rivalPointDup.y, ") ... ", info.field[rivalPointDup.y][rivalPointDup.x]);
            }
            rival.curX = rivalPointDup.x;
            rival.curY = rivalPointDup.y;
            info.samuraiInfo[info.weapon + 3] = rival;
          }
        }
      }

      if (latestField is null) {
        latestField = info.field.map!(a => a.dup).array;
      } else {
        for (int y = 0; y < info.height; ++y) {
          for (int x = 0; x < info.width; ++x) {
            if (info.field[y][x] == 9) {
              continue;
            }
            latestField[y][x] = info.field[y][x];
          }
        }
      }
      int[6] paintCount;
      for (int i = 0; i < 6; ++i) {
        paintCount[i] = 0;
      }
      for (int y = 0; y < info.height; ++y) {
        for (int x = 0; x < info.width; ++x) {
          int v = latestField[y][x];
          if (0 <= v && v < 6) {
            ++paintCount[v];
          }
        }
      }
      info.setRivalInfo(paintCount);

      if (fieldDup !is null && samuraiDup !is null) {
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
        alias Point = Tuple!(int, "x", int, "y");
        int[6] diffPrevCount;
        for (int y = 0; y < info.height; ++y) {
          for (int x = 0; x < info.width; ++x) {
            if (info.field[y][x] != fieldDup[y][x] && fieldDup[y][x] != 9) {
              int v = info.field[y][x];
              if (3 <= v && v < 6) {
                ++diffPrevCount[v];
              }
            }
          }
        }

        for (int i = 3; i < 6; ++i) {
          auto si = info.samuraiInfo[i];
          if (si.curX == -1 && si.curY == -1) {
            debug(2) {
              stderr.writeln("search ", i);
            }
            Point[] arr;
            for (int y = 0; y < info.height; ++y) {
              for (int x = 0; x < info.width; ++x) {
                for (int r = 0; r < 4; ++r) {
                  bool flag = true;
                  if (samuraiDup[i].curX != -1 && samuraiDup[i].curY != -1) {
                    flag &= Math.abs(samuraiDup[i].curX - x) + Math.abs(samuraiDup[i].curY - y) <= 1;
                  }
                  flag &= diffPrevCount[i] > 0;
                  bool done = false;
                  int diffCount = 0;
                  for (int d = 0; flag && d < ox[i - 3].length; ++d) {
                    auto pos = GameInfo.rotate(r, ox[i - 3][d], oy[i - 3][d]);
                    int px = x + pos.x;
                    int py = y + pos.y;
                    if (px < 0 || info.width <= px || py < 0 || info.height <= py) {
                      continue;
                    }
                    if (info.field[py][px] == fieldDup[py][px]) {
                      continue;
                    }
                    done |= info.field[py][px] == i;
                    flag &= info.field[py][px] == i
                        || info.field[py][px] < 3
                        || info.field[py][px] >= 8;
                    if (info.field[py][px] == i && fieldDup[py][px] != 9) {
                      ++diffCount;
                    }
                  }
                  flag &= done;
                  flag &= diffCount == diffPrevCount[i];
                  if (info.samuraiInfo[i].curX == -1 && info.samuraiInfo[i].curY == -1) {
                    flag &= (info.field[y][x] >= 3 && info.field[y][x] < 6) || info.field[y][x] == 9;
                  }
                  if (flag) {
                    arr ~= Point(x, y);
                  }
                }
              }
            }
            arr = arr.sort.uniq.array;
            debug(2) {
              foreach (k; arr) {
                stderr.writeln("\t? : ", k);
              }
            }
            if (arr.length == 1) {
              Point p = arr.front;
              int x = p.x;
              int y = p.y;
              debug(2) {
                stderr.writeln("\t\tgot it! : ", p);
              }
              si.curX = x;
              si.curY = y;
              info.samuraiInfo[i] = si;
            } else if (arr.length == 0) {
              info.setProbPlaces(i, probPointDup[i]);
              probPointDup[i] = probPointDup[i].init;
            } else {
              info.setProbPlaces(i, arr);
              probPointDup[i] = arr;
            }
          }
        }
      }

      HistoryTree root = new HistoryTree(null, info, 0);
      plan2(root);

      auto histories = root.collect();

      double[] roulette = new double[histories.length];
      double accum = 0.0;
      int i = 0;
      //next UNCO-de
      foreach (next; histories) {
        HistoryTree next_root = new HistoryTree(null, next.info, 0);
        plan2(next_root);
        auto next_histories = next_root.collect();

        double[] next_roulette = new double[next_histories.length];
        double next_accum = 0.0;
        int j = 0;
        foreach (hist; next_histories) {
          double v = Math.exp(hist.getInfo().score(NEXT_MERITS4WEAPON[info.weapon]));
          next_accum += v;
          next_roulette[j++] = next_accum;
        }
        auto idx = next_roulette.length
                    - next_roulette.assumeSorted.upperBound(uniform(0.0, next_accum)).length;

        double v = Math.exp(next.getInfo().score(MERITS4WEAPON[info.weapon])
                    + next_histories[idx].getInfo().score(NEXT_MERITS4WEAPON[info.weapon]));
        accum += v;
        roulette[i++] = accum;
      }
      debug {
        if (accum == double.infinity) {
          stderr.writeln("accum goes infinite!");
        }
      }
      auto idx = roulette.length - roulette.assumeSorted.upperBound(uniform(0.0, accum)).length;
      GameInfo best = histories[idx].getInfo();
      auto bestActions = histories[idx].getActions();
      if (best.isValid(9)) {
        best.doAction(9);
        bestActions ~= 9;
      }
      "".reduce!((l, r) => l ~ " " ~ r)(bestActions.map!(a => a.to!string)).writeln;
      stdout.flush;

      fieldDup = best.field.map!(a => a.dup).array;
      const auto ops = best.getOccupiedPoints;
      foreach (Point op; ops.byKey) {
        fieldDup[op.y][op.x] = ops[op];
      }
      samuraiDup = best.samuraiInfo.dup;
      if (best.nextAITurn2()[best.weapon] == 0) {
        auto rival = best.samuraiInfo[best.weapon + 3];
        rivalPointDup = Point(rival.curX, rival.curY);
        rivalPointDupFlag = true;
      } else {
        rivalPointDup = Point(-1, -1);
        rivalPointDupFlag = false;
      }
    }
}

