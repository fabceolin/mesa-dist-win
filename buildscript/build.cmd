@TITLE Building Mesa3D
@cd "%~dp0"
@cd ..\..\
@for %%I in ("%cd%") do @set mesa=%%~sI
@set oldpath=%PATH%
@where /q python.exe
@IF ERRORLEVEL 1 set PATH=%mesa%\Python\;%mesa%\Python\Scripts\;%PATH%
@set ERRORLEVEL=0
@set pyupd=n
@FOR /F "tokens=* USEBACKQ" %%F IN (`where python.exe`) DO @SET pythonloc=%%F
@set makoloc="%pythonloc:python.exe=%Lib\site-packages\mako"
@set sconsloc="%pythonloc:python.exe=%Scripts\scons.py"
@if NOT EXIST %makoloc% (
@python -m pip install -U pip
@python -m pip install -U wheel
@python -m pip install -U scons
@python -m pip install -U MarkupSafe
@python -m pip install -U mako
@echo.
)
@if EXIST %makoloc% set /p pyupd=Install/update python modules (y/n):
@if /I "%pyupd%"=="y" (
@python -m pip install -U pip
@python -m pip install -U wheel
@python -m pip freeze > requirements.txt
@python -m pip install -r requirements.txt --upgrade
@del requirements.txt
@echo.
)
@set abi=x86
@set /p x64=Do you want to build for x64? (y/n) Otherwise build for x86:
@if /I "%x64%"=="y" set abi=x64
@set longabi=%abi%
@if %abi%==x64 set longabi=x86_64
@set minabi=32
@if %abi%==x64 set minabi=64
@set targetabi=x86
@if %abi%==x64 set targetabi=amd64
@set hostabi=x86
@if NOT "%ProgramW6432%"=="" set hostabi=amd64
@set vsabi=%minabi%
@if NOT %targetabi%==%hostabi% set vsabi=%hostabi%_%targetabi%
@set vsenv="%ProgramFiles%
@if NOT "%ProgramW6432%"=="" set vsenv=%vsenv% (x86)
@set vsenv=%vsenv%\Microsoft Visual Studio\2017\Community\VC\Auxiliary\Build\vcvars%vsabi%.bat"
@set toolset=0
@if EXIST %vsenv% set toolset=15
@TITLE Building Mesa3D %abi%
@if %toolset% EQU 0 (
@echo Error: No Visual Studio installed.
@GOTO build_dxtn
)

:build_llvm
@set /p buildllvm=Begin LLVM build. Only needs to run once for each ABI and version. Proceed (y/n):
@if /I NOT "%buildllvm%"=="y" GOTO prep_mesa
@echo.
@cd %mesa%\llvm
@if EXIST %abi% RD /S /Q %abi%
@if EXIST cmake-%abi% RD /S /Q cmake-%abi%
@md cmake-%abi%
@cd cmake-%abi%
@set ninja=n
@set toolchain=Visual Studio %toolset%
@if EXIST %mesa%\ninja set /p ninja=Use Ninja build system instead of MsBuild (y/n); less storage device strain and maybe faster build:
@if /I "%ninja%"=="y" set toolchain=Ninja
@if /I "%ninja%"=="y" set PATH=%mesa%\ninja\;%PATH%
@if %abi%==x64 set toolchain=%toolchain% Win64
@if "%toolchain%"=="Ninja Win64" set toolchain=Ninja
@set x64compile=n
@if %hostabi%==amd64 set x64compile=1
@if /I NOT "%ninja%"=="y" set x64compile=%x64compile%2
@if %x64compile%==12 set x64compiler= -Thost=x64
@set llvmbuildsys=%CD%
@if "%toolchain%"=="Ninja" call %vsenv%
@if "%toolchain%"=="Ninja" cd %llvmbuildsys%
@echo.
@where /q cmake.exe
@IF ERRORLEVEL 1 set PATH=%mesa%\cmake\bin\;%PATH%
@set ERRORLEVEL=0
@cmake -G "%toolchain%"%x64compiler% -DLLVM_TARGETS_TO_BUILD=X86 -DCMAKE_BUILD_TYPE=Release -DLLVM_USE_CRT_RELEASE=MT -DLLVM_ENABLE_RTTI=1 -DLLVM_ENABLE_TERMINFO=OFF -DCMAKE_INSTALL_PREFIX=../%abi% ..
@echo.
@pause
@echo.
@if NOT "%toolchain%"=="Ninja" cmake --build . --config Release --target install
@if "%toolchain%"=="Ninja" ninja install
@echo.

:prep_mesa
@set PATH=%oldpath%
@cd %mesa%
@set mesapatched=0
@set branch=none
@set haltmesabuild=n
@set prepfail=0
@where /q git.exe
@IF ERRORLEVEL 1 (
@set ERRORLEVEL=0
@echo Error: Git not found. Auto-patching disabled.
@set prepfail=1
)
@if NOT EXIST mesa set mesapatched=0
@if NOT EXIST mesa echo Warning: Mesa3D source code not found.
@if NOT EXIST mesa set prepfail=%prepfail%2
@if %prepfail% EQU 12 echo Fatal: Both Mesa code and Git are missing. At least one is required. Execution halted.
@if %prepfail% EQU 12 GOTO build_dxtn
@if NOT EXIST mesa set /p haltmesabuild=Press Y to abort execution. Press any other key to download Mesa via Git:
@if /I "%haltmesabuild%"=="y" GOTO build_dxtn
@if NOT EXIST mesa set /p branch=Enter Mesa source code branch name - defaults to master:
@if "%branch%"=="" set branch=master
@if "%branch%"=="none" set branch=master
@if NOT EXIST mesa echo.
@if NOT EXIST mesa git clone --depth=1 --branch=%branch% git://anongit.freedesktop.org/mesa/mesa mesa
@cd mesa
@set LLVM=%mesa%\llvm\%abi%
@set /p mesaver=<VERSION
@if %mesaver:~-5%==devel set mesaver=%mesaver:~0,-6%
@set branch=%mesaver:~0,4%
@set /a mesaver=%mesaver:~0,2%%mesaver:~3,1%00+%mesaver:~5%
@if EXIST mesapatched.ini GOTO build_mesa
@if %prepfail% EQU 1 GOTO build_mesa
@git apply -v ..\mesa-dist-win\patches\s3tc.patch
@set mesapatched=1
@echo %mesapatched% > mesapatched.ini
@echo.

:build_mesa
@if NOT EXIST %LLVM% (
@echo Could not find LLVM, aborting mesa build.
@echo.
@pause
@GOTO build_dxtn
)
@set /p buildmesa=Begin mesa build. Proceed (y/n):
@if /i NOT "%buildmesa%"=="y" GOTO build_dxtn
@echo.
@cd %mesa%\mesa
@set openswr=n
@set sconscmd=python %sconsloc% build=release platform=windows machine=%longabi% libgl-gdi
@if %abi%==x64 set /p openswr=Do you want to build OpenSWR drivers? (y=yes):
@echo.
@if /I "%openswr%"=="y" set sconscmd=%sconscmd% swr=1
@set /p osmesa=Do you want to build off-screen rendering drivers (y/n):
@echo.
@if /I "%osmesa%"=="y" set sconscmd=%sconscmd% osmesa
@set /p graw=Do you want to build graw library (y/n):
@echo.
@if /I "%graw%"=="y" set sconscmd=%sconscmd% graw-gdi

:build_with_vs
@where /q python.exe
@IF ERRORLEVEL 1 set PATH=%mesa%\Python\;%mesa%\Python\Scripts\;%PATH%
@set ERRORLEVEL=0
@set PATH=%mesa%\flexbison\;%PATH%
@cd %mesa%\mesa

:build_mesa_exec
@set cleanbuild=n
@if EXIST build\windows-%longabi% set /p cleanbuild=Do you want to clean build (y/n):
@if EXIST build\windows-%longabi% echo.
@if /I "%cleanbuild%"=="y" RD /S /Q build\windows-%longabi%
@if NOT EXIST build md build
@if NOT EXIST build\windows-%longabi% md build\windows-%longabi%
@if NOT EXIST build\windows-%longabi%\git_sha1.h echo 0 > build\windows-%longabi%\git_sha1.h
@echo.
@%sconscmd%
@echo.

:build_dxtn
@if NOT EXIST %mesa%\mesa GOTO exit
@set PATH=%oldpath%
@if NOT EXIST %mesa%\dxtn GOTO distcreate
@if %mesaver% GEQ 17300 GOTO distcreate
@set gcchost=0
@set msys32=%mesa%\msys32
@set msys64=%mesa%\msys64
@set standalone=%mesa%\mingw-w64\%abi%\mingw%minabi%\bin
@if EXIST %msys32% set /a gcchost=%gcchost%+1
@if EXIST %msys64% set /a gcchost=%gcchost%+5
@if EXIST %standalone% set /a gcchost=%gcchost%+10
@if %gcchost% GTR 0 set /p builddxtn=Do you want to build S3 texture compression library? (y/n):
@if /i NOT "%builddxtn%"=="y" set gcchost=0
@if %gcchost% EQU 0 GOTO distcreate
@set gccpath=
@set selectgcc=0
@if %gcchost% GTR 10 (
@echo.
@echo Select GCC flavor:
@echo 1. MSYS2
@echo 2. Standalone
@set /p selectgcc=Enter choice:
@echo.
)
@if "%selectgcc%"=="1" set /a gcchost=%gcchost%-10
@if "%selectgcc%"=="2" set gcchost=10
@if %gcchost% EQU 1 set gccpath=%msys32%\mingw%minabi%\bin\;%msys32%\usr\bin\;
@if %gcchost% EQU 5 set gccpath=%msys64%\mingw%minabi%\bin\;%msys64%\usr\bin\;
@if %gcchost% EQU 6 set gccpath=%msys64%\mingw%minabi%\bin\;%msys64%\usr\bin\;
@if %gcchost% EQU 10 set gccpath=%standalone%\;
@set PATH=%gccpath%%PATH%
@cd %mesa%\dxtn
@echo.
@if EXIST %abi% RD /S /Q %abi%
@MD %abi%
@set dxtn=gcc -shared -m%minabi% -v *.c *.h -I ../mesa/include -Wl,--dll,--dynamicbase,--enable-auto-image-base,--nxcompat -o %abi%/dxtn.dll
@set msys2update=n
@if %gcchost% LSS 10 set /p msys2update=Update MSYS2 packages (y/n):
@if /I "%msys2update%"=="y" (
@pacman -Syu
@echo.
@pause
@echo.
)
@%dxtn%
@echo.

:distcreate
@set /p dist=Create or update Mesa3D distribution package (y/n):
@echo.
@if /I NOT "%dist%"=="y" GOTO exit
@cd %mesa%
@if NOT EXIST mesa-dist-win MD mesa-dist-win
@cd mesa-dist-win
@if NOT EXIST bin MD bin
@cd bin
@if EXIST %abi% RD /S /Q %abi%
@MD %abi%
@cd %abi%
@copy %mesa%\mesa\build\windows-%longabi%\gallium\targets\libgl-gdi\opengl32.dll opengl32.dll
@if %abi%==x64 copy %mesa%\mesa\build\windows-%longabi%\gallium\drivers\swr\swrAVX.dll swrAVX.dll
@if %abi%==x64 copy %mesa%\mesa\build\windows-%longabi%\gallium\drivers\swr\swrAVX2.dll swrAVX2.dll
@copy %mesa%\mesa\build\windows-%longabi%\mesa\drivers\osmesa\osmesa.dll osmesa-swrast.dll
@copy %mesa%\mesa\build\windows-%longabi%\gallium\targets\osmesa\osmesa.dll osmesa-gallium.dll
@copy %mesa%\mesa\build\windows-%longabi%\gallium\targets\graw-gdi\graw.dll graw.dll
@if %mesaver% LSS 17300 copy %mesa%\dxtn\%abi%\dxtn.dll dxtn.dll
@echo.

:exit
@pause
@exit