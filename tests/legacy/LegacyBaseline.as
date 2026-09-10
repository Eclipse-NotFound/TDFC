package {
 import flash.display.Sprite;
 import flash.desktop.NativeApplication;
 import flash.filesystem.File;
 import flash.filesystem.FileStream;
 import flash.filesystem.FileMode;
 public class LegacyBaseline extends Sprite {
  public function LegacyBaseline() {
   var st:TacticalState = new TacticalState();
   st.squadRole=2; st.suppressT=1;
   var u:Object={X:0,Y:0,scY:40,hp:100,maxhp:100,currentWeapon:{tip:3}};
   var gg:Object={X:1000,Y:0,scY:40};
   try {
    SquadCtrl.update(u,st,gg,{},[],100);
    if(st.suppressT==0 && st.lastSuppressTick!=100) {
     report("TDFC_BASELINE FAIL normal suppression end did not start cooldown: "+st.lastSuppressTick);
     NativeApplication.nativeApplication.exit(1); return;
    }
    report("TDFC_BASELINE PASS"); NativeApplication.nativeApplication.exit(0);
   } catch(e:Error) { report("TDFC_BASELINE ERROR "+e.message); NativeApplication.nativeApplication.exit(2); }
  }
  private function report(s:String):void { trace(s); var f:File = new File(File.applicationDirectory.resolvePath("out/legacy-result.txt").nativePath); var fs:FileStream=new FileStream(); fs.open(f,FileMode.WRITE); fs.writeUTFBytes(s); fs.close(); }
 }
}
