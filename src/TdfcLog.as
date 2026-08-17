package
{
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;
   import flash.utils.Dictionary;

   /**
    * TDFC 诊断日志。
    * 遵循 shared-knowledge 日志取证规范：
    *  - 版本标记行（启动时必打）；
    *  - 每功能独立计数 + 上限截断，防日志刷爆；
    *  - trace + 文件双写。
    *
    * v0.1 实测结论：桌面 AIR 对 applicationDirectory（app:/，即游戏目录）
    * 只读——File.createDirectory/写文件会被拒。模组日志统一写到
    * applicationStorageDirectory（AppData/Roaming/pfe/Local Store/，
    * 与 RConnect.log / sandy_modlog.txt 同目录，必然可写）。
    */
   public class TdfcLog
   {
      private static var counters:Dictionary = new Dictionary();
      private static var path:String = null;
      private static var fileOk:Boolean = false;

      public static function init():void
      {
         try
         {
            // applicationStorageDirectory 本身已指向 AppData/Roaming/pfe/Local Store
            // （AIR 规范：appData/<appID>/Local Store），与 RConnect/sandy 日志同目录
            var f:File = File.applicationStorageDirectory.resolvePath("tdfc.log");
            if (f.exists && f.size > Config.LOG_MAX_BYTES)
            {
               f.deleteFile(); // 超限重置
            }
            // 打开测试（追加模式下不存在则创建）
            var probe:FileStream = new FileStream();
            probe.open(f, FileMode.APPEND);
            probe.close();
            path = f.nativePath;
            fileOk = true;
         }
         catch (e:Error)
         {
            path = null;
            fileOk = false;
            trace("[TDFC] log init failed: " + e.message);
         }
         version(); // 版本标记无条件执行
      }

      public static function version():void
      {
         line("ver",
            "TDFC v" + Config.VER
            + " propVision=" + (Config.ENABLE_PROP_VISION ? 1 : 0)
            + " propGunshot=" + (Config.ENABLE_PROP_GUNSHOT ? 1 : 0)
            + " propDamage=" + (Config.ENABLE_PROP_DAMAGE ? 1 : 0)
            + " search=" + (Config.ENABLE_SEARCH ? 1 : 0)
            + " dodgeAim=" + (Config.ENABLE_DODGE_AIM ? 1 : 0)
            + " dodgeThreat=" + (Config.ENABLE_DODGE_THREAT ? 1 : 0)
            + " cover=" + (Config.ENABLE_COVER ? 1 : 0)
            + " retreat=" + (Config.ENABLE_RETREAT ? 1 : 0)
            + " testSpawn=" + (Config.ENABLE_TEST_SPAWN ? 1 : 0));
      }

      public static function line(feature:String, msg:String):void
      {
         var n:Object = counters[feature];
         var c:int = (n == null) ? 0 : int(n);
         if (c >= Config.DIAG_CAP)
         {
            return;
         }
         counters[feature] = c + 1;
         var s:String = "[TDFC] " + feature + " " + msg;
         trace(s);
         if (!fileOk || path == null)
         {
            return;
         }
         try
         {
            var f:File = File.applicationStorageDirectory.resolvePath("tdfc.log");
            var fs:FileStream = new FileStream();
            fs.open(f, FileMode.APPEND);
            fs.writeUTFBytes(s + "\n");
            fs.close();
         }
         catch (e:Error)
         {
            // 日志写入失败不打断战斗逻辑
            fileOk = false;
         }
      }

      public static function count(feature:String):int
      {
         var n:Object = counters[feature];
         return (n == null) ? 0 : int(n);
      }
   }
}