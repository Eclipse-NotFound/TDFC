package {
 import flash.display.Sprite;
 import flash.desktop.NativeApplication;
 import flash.filesystem.File;
 import flash.filesystem.FileStream;
 import flash.filesystem.FileMode;
 public class LogicTests extends Sprite {
  private var lines:Array=[],failed:int=0;
  public function LogicTests() {
   try {run();}catch(e:Error){failed++;lines.push("ERROR "+e.message+" "+e.getStackTrace());}
   lines.push("RESULT failures="+failed);
   var fs:FileStream=new FileStream();fs.open(new File(File.applicationDirectory.resolvePath("out/logic-result.txt").nativePath),FileMode.WRITE);fs.writeUTFBytes(lines.join("\n"));fs.close();
   NativeApplication.nativeApplication.exit(failed?1:0);
  }
  private function check(ok:Boolean,name:String):void {lines.push((ok?"PASS ":"FAIL ")+name);if(!ok)failed++;}
  private function sample(f:String="raider",level:int=1):Object {return {id:f+"1",family:f,cls:"UnitRaider",level:level,hero:0,boss:false,x:0,y:0,cx:0,cy:-20,height:40,hp:100,maxhp:100,fraction:2,gun:true,reload:0,role:"gun",fixed:false,weapon:{},ammo:20,shots:0};}
  private function brain(n:int=1,f:String="raider",level:int=1):BrainState {var s:Object=sample(f,level);var b:BrainState=new BrainState(n,{},EnemyProfile.make(s));b.sample=s;return b;}
  private function env():Object {return {distance:300,threat:null,slotOwned:false,squad:{coverMate:false,canSuppress:false,nearest:1000,nearX:0},covers:[],retreat:null,aimed:false};}
  private function run():void {
   var b:BrainState=brain();b.action.kind="suppress";b.until=100;b.lastSeen=99;
   TacticalMind.decide(b,env(),100);
   check(b.suppressCooldown==400 && b.suppressEnd==100,"normal suppression end starts 300-tick cooldown (legacy regression)");
   var squad:SquadMind=new SquadMind();check(squad.claim(2,1,10,20),"first suppressor claims slot");
   check(!squad.claim(2,2,11,20),"second suppressor denied");
   squad.release(2,1,30);check(!squad.available(2,329) && squad.available(2,330),"team cooldown survives role changes");
   var low:Object=EnemyProfile.make(sample("raider",1)),high:Object=EnemyProfile.make(sample("raider",40)),ranger:Object=EnemyProfile.make(sample("ranger",1));
   check(high.tier>low.tier && high.style==low.style,"progression improves cognition without changing culture");
   check(ranger.supported && ranger.family=="ranger" && ranger.tier>low.tier,"ranger supported with training bonus");
   var e1:Object=sample("raider",1);e1.hero=1;var e4:Object=sample("raider",1);e4.hero=4;
   check(EnemyProfile.make(e1).tier==EnemyProfile.make(e4).tier,"hero variant is not military rank");
   var elite:Object=sample("merc",1);elite.id="merc5";
   check(EnemyProfile.make(elite).tier>EnemyProfile.make(sample("merc",1)).tier,"explicit elite subtype improves cognition");
   var p:PerceptionModel=new PerceptionModel(),g:Object={x:100,y:0,obs:1,maxObs:1};b=brain();
   var seen:Object={visible:true,heard:false},blind:Object={visible:false,heard:false};
   for(var t:int=0;t<b.profile.confirm-1;t++)p.observe(b,g,seen,t);
   p.observe(b,g,blind,30);p.observe(b,g,seen,31);check(!b.confirmed && b.confirm==1,"broken sight resets continuous confirmation");
   for(t=32;t<70;t++)p.observe(b,g,seen,t);
   var x:Number=b.knownX;g.x=900;p.observe(b,g,blind,70);
   check(b.knownX==x && b.lastSeen==69,"occlusion does not refresh exact position");
   var receiver:BrainState=brain(2),enemy:BrainState=brain(3);receiver.sample.x=100;enemy.sample.x=100;enemy.sample.fraction=4;
   b.confirmed=true;b.lastReport=-1000;b.lastSeen=80;p.schedule([b,receiver,enemy],80);p.deliver([b,receiver,enemy],130);
   check(receiver.evidence.indexOf("同伴")>=0 && enemy.evidence=="无","reports obey current allegiance");
   p.reset();receiver.lastSeen=-1000;receiver.evidence="无";b.lastReport=-1000;b.lastSeen=200;p.schedule([b,receiver],200);receiver.sample.fraction=4;p.deliver([b,receiver],250);
   check(receiver.evidence=="无","queued report rechecks allegiance at delivery");
   var w:Object={mm:{active:false},verror:{visible:false},allStat:1,onPause:false,catPause:false,comLoad:-1,t_exit:0,loc:{gg:{sost:1}}};
   check(GameBridge.pause(w)=="","running world allowed");w.onPause=true;check(GameBridge.pause(w)!="","pause gates tactical time");w.onPause=false;w.sats={active:true};check(GameBridge.pause(w)=="SATS","SATS gates tactical time");
   b=brain(1,"raider",1);b.lastSeen=100;b.confirmed=true;b.knownX=400;b.evidence="目击";
   var br:BrainState=brain(2,"ranger",1);br.lastSeen=100;br.confirmed=true;br.knownX=400;br.evidence="目击";
   var en:Object=env();en.distance=350;
   check(TacticalMind.decide(b,en,110).kind=="advance" && TacticalMind.decide(br,en,110).kind=="hold","raider advances while ranger holds fire position");
   br.lastSeen=-1000;check(TacticalMind.decide(br,en,1000).kind=="idle","expired information ends pursuit");
   b=brain();b.sample.x=0;b.previous={weapon:b.sample.weapon,ammo:20,shots:0};b.order={kind:"cover",move:true,x:100,y:0};b.orderAt=0;b.orderX=0;b.orderY=0;
   ActionExecutor.assess(b,40);check(b.stuckUntil>40 && b.cover==null,"no actual movement triggers recovery");
   b=brain();b.previous={weapon:b.sample.weapon,ammo:20,shots:0};b.order={kind:"cover",move:true,x:3,y:0};b.orderAt=0;b.orderX=0;b.orderY=0;
   ActionExecutor.assess(b,40);check(b.stuckUntil==0 && b.orderAt==40,"arrival resets progress clock so later small drift is not treated as stuck");
   var candidates:Array=[{x:0,y:0,score:10,peekX:NaN},{x:30,y:0,score:30,peekX:60}];
   check(TacticalMind.chooseCover(candidates,low)===candidates[0] && TacticalMind.chooseCover(candidates,high)===candidates[1],"trained planning prefers cover with a firing exit");
   check(PlayerNoise.cap(-15)==0 && PlayerNoise.cap(1000)==650 && PlayerNoise.cap(60)==60,"noise caps extremes without amplifying quiet movement");
   var fake:Object={noiseRun:200,noise:400,isSit:true};PlayerNoise.update(fake);
   check(fake.noise==400 && fake.noiseRun==40,"crouching does not silence an existing gunshot");PlayerNoise.reset();check(fake.noiseRun==200,"noise control restores owned movement setting");
   var rejected:Boolean=false;try{TestSave.describe({});}catch(invalid:Error){rejected=true;}
   check(rejected,"empty save rejects rather than silently starting a new game");
   var saved:Object={est:1,pers:{persName:"Littlepip",level:29},game:{land:"random_mane"},invent:{},ver:"1.0.2"};
   check(TestSave.describe(saved).land=="random_mane" && TestSave.describe(saved).level==29,"save metadata uses native serialized field names");
   b=brain();b.lastSeen=100;b.cover={x:0,y:0,peekX:60};b.peek=true;b.peekAt=0;b.until=400;b.action.kind="peek";
   check(TacticalMind.decide(b,env(),150).kind=="peek" && b.peekAt==0,"walking toward peek point does not consume firing window");
   b.sample.x=60;TacticalMind.decide(b,env(),160);
   check(b.peekAt==178 && TacticalMind.decide(b,env(),178).kind=="hide","peek timer starts after arrival then returns to cover");
   var changed:Object=env();changed.coverSafe=false;TacticalMind.decide(b,changed,179);
   check(b.cover==null,"cover loses its reservation when remembered target gets a clear shot");
   b=brain();b.unit={jumpdy:15,mostLaz:true,isLaz:1};ActionExecutor.commitGround(b,true);
   check(b.unit.jumpdy==0 && !b.unit.mostLaz && b.unit.isLaz==0,"ground cover commitment prevents competing native jump and climb");
   ActionExecutor.commitGround(b,false);check(b.unit.jumpdy==15 && b.unit.mostLaz,"ending cover restores native mobility");
  }
 }
}
