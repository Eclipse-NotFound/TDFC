package
{
   /**
    * 感知层（v0.4）：玩家噪声治理 + 敌人感知姿态。
    *
    * 机制（1.02 反编译锚点）：
    *  - 敌人"起疑"通道唯一入口 = 玩家 noise 字段（listen(gg) 判定，
    *    半径 = noise×ear×earMult，见 entities/facts/enemy-ai-drive-interfaces）。
    *   模组无法改 listen 本身，但可以完全治理 gg.noise → 实现：
    *     * 距离衰减：半径模型下噪声值=听觉半径；调小噪声 = 远距离自然衰减
    *     * 跑(>12)>走(>7)>慢走(>3)>趴行/坐姿(0) 的分级
    *     * 武器噪声封顶（原版可达 1000+，半径过大=隔房听见）
    *  - 敌人视觉：vanilla look() 的"背后盲区"（vKonus==0 时背后仅 detecting
    *    半径可见）被 overLook=true 默认旁路；vKonus/vAngle 全游戏零赋值
    *    （锥形判定存在但从未启用）。模组每帧写：
    *     * overLook=false → 背后盲区生效（所有敌人）
    *     * vAngle=朝向角 + vKonus=锥宽 → 智能层真实锥形视野
    */
   public class Perception
   {
      /** 玩家噪声治理：按移动状态分级写 gg.noise（跑>走>慢>趴行无声），武器封顶。 */
      public static function governPlayerNoise(gg:*):void
      {
         var spd:Number = Math.abs(TdfcMain.num(gg, "dx", 0))
            + Math.abs(TdfcMain.num(gg, "dy", 0));
         var n:Number = 0;
         var sit:Boolean = (gg["isSit"] == true);
         if (!sit)
         {
            if (spd > 12)
            {
               n = Config.NOISE_RUN;
            }
            else if (spd > 7)
            {
               n = Config.NOISE_WALK;
            }
            else if (spd > 3)
            {
               n = Config.NOISE_SLOW;
            }
         }
         // 武器噪声（vanilla makeNoise 已写入）封顶
         var wn:Number = TdfcMain.num(gg, "noise", 0);
         if (wn > Config.NOISE_WEAPON_CAP)
         {
            wn = Config.NOISE_WEAPON_CAP;
         }
         if (wn > n)
         {
            n = wn;
         }
         if (TdfcMain.num(gg, "noise", 0) != n)
         {
            try { gg["noise"] = n; } catch (e:Error) {}
         }
      }

      /** 敌人感知姿态：overLook=false 激活背后盲区；智能层写锥形视野(vAngle+vKonus)。 */
      public static function governEnemySense(u:*, cls:String):void
      {
         try
         {
            if (u["overLook"] == true)
            {
               u["overLook"] = false;
            }
            if (TdfcMain.intelTier(cls) <= 1)
            {
               // 朝向角：storona>0(朝右)=0，否则 PI（与 look() 的 atan2 约定一致）
               var face:Number = (TdfcMain.num(u, "storona", 1) > 0) ? 0 : Math.PI;
               if (TdfcMain.num(u, "vAngle", 0) != face)
               {
                  u["vAngle"] = face;
               }
               if (TdfcMain.num(u, "vKonus", 0) <= 0)
               {
                  u["vKonus"] = Config.VISION_CONE;
               }
            }
         }
         catch (e:Error) {}
      }
   }
}