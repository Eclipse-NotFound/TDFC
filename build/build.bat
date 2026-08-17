@echo off
rem TDFC 模组构建脚本
rem 依赖：C:\Users\micha\Documents\_sandevistan_dev\flexsdk\bin\mxmlc
rem        + airsdk 的 airglobal.swc（路径见 build/tdfc-config.xml）
rem 输出：release\TDFCMod.swf
rem 部署：pfe.swf 的 loader 已由 FFDec 合并（见 design/ 与 state/ 记录），
rem        替换 release\TDFCMod.swf 后重启游戏即可生效。

cd /d "%~dp0.."
"C:\Users\micha\Documents\_sandevistan_dev\flexsdk\bin\mxmlc" -load-config build\tdfc-config.xml -output release\TDFCMod.swf src\TDFCMod.as
