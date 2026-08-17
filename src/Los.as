package
{
   /**
    * 瓦片视线判定（TDFC 自实现）。
    * 复刻原版 Unit.look 的遮挡规则：沿线段按 9px（World.maxdelta）采样，
    * 命中 phis==1 且落在矩形内的瓦片视为遮挡。
    * 全部走 public API（loc.getAbsTile / Tile 公开字段），模组侧无 internal 依赖。
    */
   public class Los
   {
      public static const SAMPLE:Number = 9;

      /**
       * 从 (x0,y0) 到 (x1,y1) 是否有视线。
       * loc: Location 实例（动态对象）。
       */
      public static function clear(loc:*, x0:Number, y0:Number, x1:Number, y1:Number):Boolean
      {
         var dx:Number = x1 - x0;
         var dy:Number = y1 - y0;
         var dmax:Number = Math.max(Math.abs(dx), Math.abs(dy));
         if (dmax < 1)
         {
            return true;
         }
         var steps:int = Math.floor(dmax / SAMPLE) + 1;
         for (var i:int = 1; i < steps; i++)
         {
            var px:Number = x0 + dx * i / steps;
            var py:Number = y0 + dy * i / steps;
            var t:* = null;
            try
            {
               t = loc["getAbsTile"](px, py);
            }
            catch (e:Error)
            {
               return false; // 访问失败按遮挡处理（保守）
            }
            if (t != null && t["phis"] == 1)
            {
               if (px >= t["phX1"] && px <= t["phX2"] && py >= t["phY1"] && py <= t["phY2"])
               {
                  return false;
               }
            }
         }
         return true;
      }

      /**
       * 单位到玩家的视线（目视点：单位中心偏上，近似原版 eye 高度）。
       */
      public static function toPlayer(u:*, loc:*, gg:*, range:Number):Boolean
      {
         var ex:Number = u["X"];
         var ey:Number = u["Y"] - (u["scY"] || 40) * 0.75;
         var px:Number = gg["X"];
         var py:Number = gg["Y"] - (gg["scY"] || 40) * 0.6;
         var ddx:Number = px - ex;
         var ddy:Number = py - ey;
         if (ddx * ddx + ddy * ddy > range * range)
         {
            return false;
         }
         return clear(loc, ex, ey, px, py);
      }
   }
}
