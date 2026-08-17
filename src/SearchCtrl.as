package
{
   /**
    * 记忆与搜索控制器（Phase 1 信息层）。
    *
    * 机制（原版锚点）：
    *  - 敌人交战期间 celUnit==玩家 → TDFC 逐帧记录 lastSeen；
    *  - 丢失目标（celUnit 离开玩家）且曾在战斗 → 进入搜索：
    *    * 每 SEARCH_RECHECK tick 用自实现 LOS 复查玩家（不依赖原版 look 的
    *      vision 半径），看到即 setCel(gg) 交还交战；
    *    * 每 SEARCH_REFRESH tick 用 alarma 把调查点重新指回 lastSeen
    *      （原版 aiSpok>0 时调查点有效，且每 5 tick 自随机 ±40 抖动）；
    *    * SEARCH_TIMEOUT 后放弃，交还原版（aiSpok 自然衰减归零，回闲逛）。
    *  - 全程不读写 internal 字段。
    */
   public class SearchCtrl
   {
      public static const PHASE_NONE:int = 0;
      public static const PHASE_SEARCH:int = 1;

      /**
       * 每帧更新单个单位的搜索状态。
       * 返回 true 表示该帧 TDFC 对其发出了行为指令（诊断用）。
       */
      public static function update(u:*, st:TacticalState, gg:*, loc:*, tick:int):Boolean
      {
         var acted:Boolean = false;

         // 正在交战：记录最后目击位置，并清掉搜索态（原版已接管）
         if (u["celUnit"] === gg)
         {
            st.lastSeenX = gg["X"];
            st.lastSeenY = gg["Y"];
            st.lastSeenTick = tick;
            if (st.searchPhase == PHASE_SEARCH)
            {
               st.searchPhase = PHASE_NONE;
               TdfcLog.line("search", "RESUME " + TdfcMain.tag(u));
            }
            return false;
         }

         // 不在交战：
         //  - 如果此前刚失去目标（前一帧在交战）→ 启动搜索
         if (st.prevCelGG && st.searchPhase == PHASE_NONE)
         {
            st.searchPhase = PHASE_SEARCH;
            st.searchTick = Config.SEARCH_TIMEOUT;
            st.recheckTick = 0;
            st.refreshTick = 0;
            st.searchX = st.lastSeenX + TdfcMain.jitter(Config.HEAR_ERR);
            st.searchY = st.lastSeenY + TdfcMain.jitter(Config.HEAR_ERR);
            TdfcLog.line("search", "START " + TdfcMain.tag(u)
               + " at " + int(st.lastSeenX) + "," + int(st.lastSeenY));
         }

         if (st.searchPhase != PHASE_SEARCH)
         {
            return false;
         }

         // 敌人中途拿到了其他目标（不是玩家）→ 停止干预
         if (u["celUnit"] != null)
         {
            st.searchPhase = PHASE_NONE;
            return false;
         }

         // 超时 → 放弃，交还原版
         if (st.searchTick <= 0)
         {
            st.searchPhase = PHASE_NONE;
            TdfcLog.line("search", "TIMEOUT " + TdfcMain.tag(u));
            return false;
         }
         st.searchTick--;

         // 视线复查：看到玩家 → 直接交战
         st.recheckTick--;
         if (st.recheckTick <= 0)
         {
            st.recheckTick = Config.SEARCH_RECHECK;
            if (Los.toPlayer(u, loc, gg, Config.SEARCH_REACQ_RANGE))
            {
               try
               {
                  u["setCel"](gg);
                  st.searchPhase = PHASE_NONE;
                  TdfcLog.line("search", "REACQ " + TdfcMain.tag(u));
                  acted = true;
               }
               catch (e:Error) {}
               return acted;
            }
         }

         // 调查点刷新：重新指回最后目击位置附近
         st.refreshTick--;
         if (st.refreshTick <= 0)
         {
            st.refreshTick = Config.SEARCH_REFRESH;
            try
            {
               u["alarma"](st.searchX + TdfcMain.jitter(40), st.searchY + TdfcMain.jitter(40));
               acted = true;
            }
            catch (e:Error) {}
         }
         return acted;
      }
   }
}
