#!/bin/bash
# shellcheck disable=SC2034,SC1090,SC1117,SC1091,SC2119
shopt -s extglob

if [[ -z $LOCALBUILDDIR ]]; then
    printf '%s\\n' \\
        "Something went wrong." \\
        "MSYSTEM: $MSYSTEM" \\
        "pwd: $(cygpath -w "$(pwd)")" \\
        "fstab: " \\
        "$(cat /etc/fstab)" \\
        "Create a new issue and upload all logs you can find, especially compile.log"
    read -r -p "Enter to continue" ret
    exit 1
fi
FFMPEG_BASE_OPTS=("--pkg-config=pkgconf" --pkg-config-flags="--keep-system-libs --keep-system-cflags --static" "--cc=$CC" "--cxx=$CXX" "--ld=$CXX" "--extra-cxxflags=-fpermissive" "--extra-cflags=-Wno-int-conversion")
printf '\\nBuild start: %(%F %T %z)T\\n' -1 >> "$LOCALBUILDDIR/newchangelog"

printf '#!/bin/bash\\nbash %s %s\\n' "$LOCALBUILDDIR/media-suite_compile.sh" "$*" > "$LOCALBUILDDIR/last_run"

while true; do
    case $1 in
    --cpuCount=* ) cpuCount=${1#*=} && shift ;;
    --build32=* ) build32=${1#*=} && shift ;;
    --build64=* ) build64=${1#*=} && shift ;;
    --mp4box=* ) mp4box=${1#*=} && shift ;;
    --rtmpdump=* ) rtmpdump=${1#*=} && shift ;;
    --vpx=* ) vpx=${1#*=} && shift ;;
    --x264=* ) x264=${1#*=} && shift ;;
    --x265=* ) x265=${1#*=} && shift ;;
    --other265=* ) other265=${1#*=} && shift ;;
    --flac=* ) flac=${1#*=} && shift ;;
    --fdkaac=* ) fdkaac=${1#*=} && shift ;;
    --mediainfo=* ) mediainfo=${1#*=} && shift ;;
    --sox=* ) sox=${1#*=} && shift ;;
    --ffmpeg=* ) ffmpeg=${1#*=} && shift ;;
    --ffmpegUpdate=* ) ffmpegUpdate=${1#*=} && shift ;;
    --ffmpegPath=* ) ffmpegPath="${1#*=}"; shift ;;
    --ffmpegChoice=* ) ffmpegChoice=${1#*=} && shift ;;
    --mplayer=* ) mplayer=${1#*=} && shift ;;
    --mpv=* ) mpv=${1#*=} && shift ;;
    --deleteSource=* ) deleteSource=${1#*=} && shift ;;
    --license=* ) license=${1#*=} && shift ;;
    --standalone=* ) standalone=${1#*=} && shift ;;
    --stripping* ) stripping=${1#*=} && shift ;;
    --packing* ) packing=${1#*=} && shift ;;
    --logging=* ) logging=${1#*=} && shift ;;
    --bmx=* ) bmx=${1#*=} && shift ;;
    --aom=* ) aom=${1#*=} && shift ;;
    --faac=* ) faac=${1#*=} && shift ;;
    --exhale=* ) exhale=${1#*=} && shift ;;
    --ffmbc=* ) ffmbc=${1#*=} && shift ;;
    --curl=* ) curl=${1#*=} && shift ;;
    --cyanrip=* ) cyanrip=${1#*=} && shift ;;
    --ripgrep=* ) ripgrep=${1#*=} && shift ;;
    --rav1e=* ) rav1e=${1#*=} && shift ;;
    --dav1d=* ) dav1d=${1#*=} && shift ;;
    --libavif=* ) libavif=${1#*=} && shift ;;
    --libheif=* ) libheif=${1#*=} && shift ;;
    --jpegxl=* ) jpegxl=${1#*=} && shift ;;
    --av1an=* ) av1an=${1#*=} && shift ;;
    --vvc=* ) vvc=${1#*=} && shift ;;
    --uvg266=* ) uvg266=${1#*=} && shift ;;
    --vvenc=* ) vvenc=${1#*=} && shift ;;
    --vvdec=* ) vvdec=${1#*=} && shift ;;
    --jq=* ) jq=${1#*=} && shift ;;
    --jo=* ) jo=${1#*=} && shift ;;
    --dssim=* ) dssim=${1#*=} && shift ;;
    --gifski=* ) gifski=${1#*=} && shift ;;
    --avs2=* ) avs2=${1#*=} && shift ;;
    --dovitool=* ) dovitool=${1#*=} && shift ;;
    --hdr10plustool=* ) hdr10plustool=${1#*=} && shift ;;
    --timeStamp=* ) timeStamp=${1#*=} && shift ;;
    --noMintty=* ) noMintty=${1#*=} && shift ;;
    --ccache=* ) ccache=${1#*=} && shift ;;
    --svthevc=* ) svthevc=${1#*=} && shift ;;
    --svtav1=* ) svtav1=${1#*=} && shift ;;
    --svtvp9=* ) svtvp9=${1#*=} && shift ;;
    --xvc=* ) xvc=${1#*=} && shift ;;
    --vlc=* ) vlc=${1#*=} && shift ;;
    --zlib=* ) zlib=${1#*=} && shift ;;
    --exitearly=* ) exitearly=${1#*=} && shift ;;
    # --autouploadlogs=* ) autouploadlogs=${1#*=} && shift ;;
    -- ) shift && break ;;
    -* ) echo "Error, unknown option: '$1'." && exit 1 ;;
    * ) break ;;
    esac
done

[[ $ccache != y ]] && export CCACHE_DISABLE=1

# shellcheck source=media-suite_deps.sh
source "$LOCALBUILDDIR"/media-suite_deps.sh

# shellcheck source=media-suite_helper.sh
source "$LOCALBUILDDIR"/media-suite_helper.sh

if [[ $exitearly = EE1 ]]; then
    do_simple_print -p '\\n\\t'"${orange}Exit due to env var MABS_EXIT_EARLY set to EE1"
    exit 0
fi

do_simple_print -p "${orange}Warning: We will not accept any issues lacking any form of logs or logs.zip!$reset"

buildProcess() {
set_title
do_simple_print -p '\\n\\t'"${orange}Starting $bits compilation of all tools$reset"
[[ -f $HOME/custom_build_options ]] &&
    echo "Imported custom build options (unsupported)" &&
    source "$HOME"/custom_build_options

cd_safe "$LOCALBUILDDIR"

do_getFFmpegConfig "$license"
declare -A MPV_OPTS="($(do_getMpvConfig))"

do_fix_pkgconfig_abspaths
do_clean_old_builds

# In case a build was interrupted before reversing hide_conflicting_libs
[[ -d $LOCALDESTDIR/opt/cyanffmpeg ]] &&
    hide_conflicting_libs -R "$LOCALDESTDIR/opt/cyanffmpeg"
hide_conflicting_libs -R
do_hide_all_sharedlibs
create_ab_pkgconfig
create_cmake_toolchain
create_ab_ccache

set_title "compiling global tools"
do_simple_print -p '\\n\\t'"${orange}Starting $bits compilation of global tools${reset}"

if [[ $bits = 32bit && $av1an != n ]]; then
    do_simple_print "${orange}Av1an cannot be compiled due to Vapoursynth being broken on 32-bit and will be disabled"'!'"${reset}"
    _reenable_av1an=$av1an # so that av1an can be built if both 32 bit and 64 bit targets are enabled
    av1an=n
fi

if [[ ! -z $_reenable_av1an ]] && [[ $bits = 64bit ]]; then
    av1an=$_reenable_av1an
    unset _reenable_av1an
fi

if [[ $packing = y &&
    ! "$(/opt/bin/upx -V 2> /dev/null | head -1)" = "upx 5.0.0" ]] &&
    do_wget -h 8c34b9cec2c225bf71f43cf2b788043d0d203d23edb54f649fbec16f34938d80 \\
        "https://github.com/upx/upx/releases/download/v5.0.0/upx-5.0.0-win32.zip"; then
    do_install upx.exe /opt/bin/upx.exe
fi

if [[ "$ripgrep|$rav1e|$dssim|$libavif|$dovitool|$hdr10plustool" = *y* ]] ||
    [[ $av1an != n ]] || [[ $gifski != n ]] || [[ $zlib = rs ]] || enabled librav1e; then
    do_pacman_install rust
    [[ $CC =~ clang ]] && rust_target_suffix="-llvm"
fi

if [[ $libavif = y ]] || [[ $dovitool = y ]] || [[ $zlib = rs ]] || enabled librav1e; then
    do_pacman_install cargo-c
fi

_check=(libz.a zlib.pc)
_zlib_uninstall=(lib/cmake/{zlib,minizip} z{conf,lib,lib_name_mangling}.h include/minizip libminizip.{,l}a minizip.pc)
if [[ $zlib = n ]]; then
    # uninstall existing zlib files, if the user switched from building zlib to using the msys2 package
    do_uninstall "${_check[@]}" "${_zlib_uninstall[@]}"
    zlib_dir="$MINGW_PREFIX"
else
    zlib_dir="$LOCALDESTDIR"
    if [[ $zlib = y ]]; then
        [[ $standalone = y ]] && _check+=(bin-global/mini{,un}zip.exe)
        if do_vcs "$SOURCE_REPO_ZLIB"; then
            do_uninstall "${_check[@]}" "${_zlib_uninstall[@]}"
            sed -i 's; -L${sharedlibdir};;' zlib.pc.in
            do_cmakeinstall -DZLIB_BUILD_{TESTING,SHARED}=OFF -DZLIB_INSTALL_COMPAT_DLL=OFF
            if [[ $standalone = y ]]; then
                cd_safe ../contrib/minizip
                sed -i 's/Libs.private.*/& -lbz2/' minizip.pc.in
                do_autoreconf
                CFLAGS+=" -DHAVE_BZIP2" do_separate_confmakeinstall global --enable-demos LIBS="-lbz2"
            fi
            [[ -f "$LOCALDESTDIR"/lib/libzs.a ]] && mv -f "$LOCALDESTDIR"/lib/libz{s,}.a
            do_checkIfExist
        fi
    elif [[ $zlib = chromium ]]; then
        [[ $standalone = y ]] && _check+=(bin-global/mini{,g}zip.exe)
        if do_vcs "$SOURCE_REPO_ZLIBCHROMIUM"; then
            do_uninstall "${_check[@]}" "${_zlib_uninstall[@]}"
            extracommands=()
            [[ $standalone = y ]] && extracommands=(-DBUILD_MINIZIP_BIN=YES -DBUILD_MINIGZIP=YES)
            # these macros are for some reason not set, even though they should be according to CMakeLists.txt
            local zlib_macros="-DINFLATE_CHUNK_SIMD_SSE2 -DADLER32_SIMD_SSSE3 -DINFLATE_CHUNK_READ_64LE -DCRC32_SIMD_SSE42_PCLMUL -DDEFLATE_SLIDE_HASH_SSE2 -D_LARGEFILE64_SOURCE=1 -DX86_WINDOWS"
            sed -i 's; -L${sharedlibdir};;' zlib.pc.cmakein
            # add missing header and source files needed for compilation, force all executables to link with static zlib, and name libraries correctly with -DUNIX=OFF
            sed -e 's;ioapi.h;ioapi.h contrib/minizip/iowin32.c contrib/minizip/iowin32.h;' \\
                -e 's;zlib);zlibstatic);' -e 's;BUILD_SHARED_LIBS AND WIN32;MINGW;' \\
                -e 's;zlib PROPERTIES SUFFIX "1.dll";zlib zlibstatic PROPERTIES OUTPUT_NAME z;' -i CMakeLists.txt
            # the win32 dir is missing, so copy the folder from original zlib
            do_wget -c -r -q "https://github.com/madler/zlib/archive/refs/heads/develop.tar.gz"
            tar --strip-components=1 -xzf develop.tar.gz zlib-develop/win32
            do_cmakeinstall -DUNIX=OFF -DINSTALL_PKGCONFIG_DIR="${LOCALDESTDIR}/lib/pkgconfig" \\
                -DUSE_ZLIB_RABIN_KARP_HASH=ON -DENABLE_SIMD_OPTIMIZATIONS=ON \\
                -DCMAKE_C_FLAGS="${CFLAGS} ${zlib_macros} -msse4.2 -mpclmul" "${extracommands[@]}"
            [[ $standalone = y ]] && do_install minizip_bin.exe bin-global/minizip.exe &&
                do_install minigzip_bin.exe bin-global/minigzip.exe
            # there's no option to disable building the shared library, so delete them manually
            [[ -f "$LOCALDESTDIR"/lib/libz.dll.a ]] && rm -f "$LOCALDESTDIR"/lib/libz.dll.a
            [[ -f "$LOCALDESTDIR"/bin/libz.dll ]] && rm -f "$LOCALDESTDIR"/bin/libz.dll
            do_checkIfExist
            unset extracommands
        fi
    elif [[ $zlib = cloudflare ]]; then
        [[ $standalone = y ]] && _check+=(bin-global/minigzip.exe)
        if do_vcs "$SOURCE_REPO_ZLIBCLOUDFLARE"; then
            do_uninstall "${_check[@]}" "${_zlib_uninstall[@]}"
            extracommands=()
            [[ $standalone = y ]] && extracommands=(-DBUILD_EXAMPLES=YES)
            sed -i 's; -L${sharedlibdir};;' zlib.pc.in
            do_cmakeinstall -DCMAKE_POLICY_VERSION_MINIMUM=3.5 "${extracommands[@]}"
            [[ $standalone = y ]] && do_install minigzip.exe bin-global/
            do_checkIfExist
            unset extracommands
        fi
        if enabled zlib; then
            do_addOption --extra-cflags=-Wno-error=incompatible-pointer-types
        fi
    elif [[ $zlib = ng ]]; then
        [[ $standalone = y ]] && _check+=(bin-global/mini{,g}zip.exe)
        if do_vcs "$SOURCE_REPO_ZLIBNG"; then
            do_uninstall "${_check[@]}" "${_zlib_uninstall[@]}"
            do_cmakeinstall global -DZLIB_COMPAT=ON -DWITH_GTEST=OFF -DZLIB_ENABLE_TESTS=OFF
            if [[ $standalone = y ]] &&
                do_vcs "$SOURCE_REPO_MINIZIPNG"; then
                do_cmakeinstall global -DMZ_BUILD_TESTS=ON
            fi
            do_checkIfExist
        fi
    elif [[ $zlib = rs ]]; then
        if do_vcs "$SOURCE_REPO_ZLIBRS"; then
            do_uninstall "${_check[@]}" "${_zlib_uninstall[@]}"
            cd_safe libz-rs-sys-cdylib
            # edit package metadata and library name to match zlib
            sed -e 's;libz_rs;libz;' -e 's;z_rs;z;' -i Cargo.toml
            PKG_CONFIG="$LOCALDESTDIR/bin/ab-pkg-config-static.bat" \\
                log "rust.capi" cargo capi build \\
                --release --jobs "$cpuCount" --prefix="$LOCALDESTDIR"
            do_install "target/$CARCH-pc-windows-gnu$rust_target_suffix/release/libz.a" libz.a
            do_install "target/$CARCH-pc-windows-gnu$rust_target_suffix/release/libz.pc" zlib.pc
            do_checkIfExist
        fi
    fi
fi
unset _zlib_uninstall

_check=(bin-global/rg.exe)
if [[ $ripgrep = y ]] &&
    do_vcs "$SOURCE_REPO_RIPGREP"; then
    do_uninstall "${_check[@]}"
    do_rust
    do_install "target/$CARCH-pc-windows-gnu$rust_target_suffix/release/rg.exe" bin-global/
    do_checkIfExist
fi

_check=(bin-global/jo.exe)
if [[ $jo = y ]] &&
    do_vcs "$SOURCE_REPO_JO"; then
    do_mesoninstall global
    do_checkIfExist
fi

_deps=("$MINGW_PREFIX"/lib/pkgconfig/oniguruma.pc)
_check=(bin-global/jq.exe)
if [[ $jq = y ]] &&
    do_vcs "$SOURCE_REPO_JQ"; then
    do_pacman_install -m bison flex
    do_pacman_install oniguruma
    do_uninstall "${_check[@]}"
    do_autoreconf
    CFLAGS+=' -D_POSIX_C_SOURCE' YFLAGS='--warnings=no-yacc' \\
        do_separate_conf global --enable-{all-static,pthread-tls,maintainer-mode} --disable-docs
    do_make && do_install jq.exe bin-global/
    do_checkIfExist
fi

_check=(bin-global/dssim.exe)
if [[ $dssim = y ]] &&
    do_vcs "$SOURCE_REPO_DSSIM"; then
    do_uninstall "${_check[@]}"
    CFLAGS+=" -fno-PIC" do_rust
    do_install "target/$CARCH-pc-windows-gnu$rust_target_suffix/release/dssim.exe" bin-global/
    do_checkIfExist
fi

if [[ $gifski != n ]]; then
    if [[ $gifski = video ]]; then
        _check=("$LOCALDESTDIR"/opt/gifskiffmpeg/lib/pkgconfig/lib{av{codec,device,filter,format,util},swscale}.pc)
        if flavor=gifski do_vcs "https://git.ffmpeg.org/ffmpeg.git#branch=release/6.1"; then
            do_uninstall "$LOCALDESTDIR"/opt/gifskiffmpeg
            [[ -f config.mak ]] && log "distclean" make distclean
            create_build_dir gifski
            mapfile -t audio_codecs < <(
                sed -n '/audio codecs/,/external libraries/p' ../libavcodec/allcodecs.c |
                sed -n 's/^[^#]*extern.* *ff_\\([^ ]*\\)_decoder;/\\1/p')
            mapfile -t image_demuxers < <(
                sed -n '/image demuxers/,/external libraries/p' ../libavformat/allformats.c |
                sed -n 's/^[^#]*extern.* *ff_\\([^ ]*\\)_demuxer;/\\1/p')
            config_path=.. do_configure "${FFMPEG_BASE_OPTS[@]}" \\
                --prefix="$LOCALDESTDIR/opt/gifskiffmpeg" \\
                --enable-static --disable-shared --disable-programs \\
                --disable-autodetect --disable-everything \\
                --disable-{debug,doc,network,protocols} \\
                --enable-{decoders,demuxers} \\
                --enable-filter=format,fps,scale --enable-protocol=file \\
                --disable-bsf=evc_frame_merge,media100_to_mjpegb,vp9_superframe_split \\
                --disable-decoder="$(IFS=, ; echo "${audio_codecs[*]}")" \\
                --disable-demuxer="$(IFS=, ; echo "${image_demuxers[*]}"),image2pipe,yuv4mpegpipe"
            do_make && do_makeinstall
            files_exist "${_check[@]}" && touch ../"build_successful${bits}_gifski"
            unset audio_codecs image_demuxers gifski_ffmpeg_opts
        fi
        old_PKG_CONFIG_PATH=$PKG_CONFIG_PATH
        PKG_CONFIG_PATH=$LOCALDESTDIR/opt/gifskiffmpeg/lib/pkgconfig:$PKG_CONFIG_PATH
    fi

    _check=(bin-global/gifski.exe)
    if do_vcs "$SOURCE_REPO_GIFSKI"; then
        do_uninstall "${_check[@]}"
        extracommands=()
        if [[ $gifski = video ]]; then
            extracommands=("--release" "--features=video-prebuilt-static")
            do_pacman_install clang
        fi
        PKG_CONFIG="$LOCALDESTDIR/bin/ab-pkg-config-static.bat" \\
            LIBCLANG_PATH="$MINGW_PREFIX/bin" do_rust "${extracommands[@]}"
        do_install "target/$CARCH-pc-windows-gnu$rust_target_suffix/release/gifski.exe" bin-global/
        do_checkIfExist
        unset extracommands
    fi
    if [[ $gifski = video ]]; then
        PKG_CONFIG_PATH=$old_PKG_CONFIG_PATH
        unset old_PKG_CONFIG_PATH
    fi
fi

_deps=("$zlib_dir"/lib/libz.a)
_check=(libxml2.a libxml2/libxml/xmlIO.h libxml-2.0.pc)
if { enabled_any libxml2 libbluray || [[ $cyanrip = y ]] || ! mpv_disabled libbluray; } &&
    do_vcs "$SOURCE_REPO_LIBXML2"; then
    do_uninstall include/libxml2/libxml "${_check[@]}"
    extracommands=("-DLIBXML2_WITH_PYTHON=OFF" "-DLIBXML2_WITH_TESTS=OFF")
    [[ $standalone = y ]] || extracommands+=("-DLIBXML2_WITH_PROGRAMS=OFF")
    do_cmakeinstall "${extracommands[@]}"
    do_checkIfExist
    unset extracommands
fi

# Fixes an issue with ordering with libbluray libxml2 and libz and liblzma
# Probably caused by https://gitlab.gnome.org/GNOME/libxml2/-/commit/93e8bb2a402012858500b608b4146cd5c756e34d
grep_or_sed Requires.private "$LOCALDESTDIR/lib/pkgconfig/libxml-2.0.pc" 's/Requires:/Requires.private:/'

if [[ $ffmpeg != no ]] && enabled libaribb24; then
    _deps=("$zlib_dir"/lib/libz.a)
    _check=(libpng.{pc,{,l}a} libpng16.{pc,{,l}a} libpng16/png.h)
    if do_vcs "$SOURCE_REPO_LIBPNG"; then
        do_uninstall include/libpng16 "${_check[@]}"
        do_autoupdate
        do_separate_confmakeinstall --with-pic
        do_checkIfExist
    fi

    _deps=(libpng.{pc,a} libpng16.{pc,a})
    _check=(aribb24.pc libaribb24.{,l}a)
    if do_vcs "$SOURCE_REPO_ARRIB24"; then
        do_patch "https://raw.githubusercontent.com/BtbN/FFmpeg-Builds/master/patches/aribb24/12.patch"
        do_patch "https://raw.githubusercontent.com/BtbN/FFmpeg-Builds/master/patches/aribb24/13.patch"
        do_patch "https://raw.githubusercontent.com/BtbN/FFmpeg-Builds/master/patches/aribb24/17.patch"
        do_uninstall include/aribb24 "${_check[@]}"
        do_autoreconf
        do_separate_confmakeinstall --with-pic
        do_checkIfExist
    fi
fi

if [[ $mplayer = y || $mpv = y ]] ||
    { [[ $ffmpeg != no ]] && enabled_any libass libfreetype {lib,}fontconfig libfribidi; }; then
    do_pacman_remove freetype fontconfig harfbuzz fribidi

    _check=(libfreetype.a freetype2.pc)
    [[ $ffmpeg = sharedlibs ]] && _check+=(bin-video/libfreetype-6.dll libfreetype.dll.a)
    if do_vcs "$SOURCE_REPO_FREETYPE"; then
        do_uninstall include/freetype2 bin-global/freetype-config \\
            bin{,-video,-global}/libfreetype-6.dll libfreetype.dll.a "${_check[@]}"
        extracommands=(-D{harfbuzz,png,bzip2,brotli,zlib,tests}"=disabled")
        [[ $ffmpeg = sharedlibs ]] && extracommands+=(--default-library=both)
        do_mesoninstall global "${extracommands[@]}"
        [[ $ffmpeg = sharedlibs ]] && do_install "$LOCALDESTDIR"/bin-global/libfreetype-6.dll bin-video/
        do_checkIfExist
        unset extracommands
    fi

    _deps=(libfreetype.a)
    _check=(libfontconfig.a fontconfig.pc)
    if [[ $ffmpeg = sharedlibs ]]; then
        enabled_any {lib,}fontconfig && do_removeOption "--enable-(lib|)fontconfig"
        _check+=(bin-global/libfontconfig-1.dll libfontconfig.dll.a)
    fi
    if enabled_any {lib,}fontconfig &&
        do_vcs "$SOURCE_REPO_FONTCONFIG"; then
        do_uninstall include/fontconfig "${_check[@]}"
        do_pacman_install gperf
        extracommands=()
        [[ $standalone = y ]] || extracommands+=(-Dtools=disabled)
        [[ $ffmpeg = sharedlibs ]] && extracommands+=(--default-both-libraries=both)
        do_mesoninstall global -D{doc,tests}=disabled -Diconv=enabled "${extracommands[@]}"
        do_checkIfExist
        unset extracommands
    fi
    # Prevents ffmpeg from trying to link to a broken libfontconfig.dll.a
    [[ $ffmpeg = sharedlibs ]] || do_uninstall bin-global/libfontconfig-1.dll libfontconfig.dll.a

    _deps=(libfreetype.a)
    _check=(libharfbuzz.a harfbuzz.pc)
    [[ $ffmpeg = sharedlibs ]] && _check+=(libharfbuzz.dll.a bin-video/libharfbuzz-{subset-,}0.dll)
    if do_vcs "$SOURCE_REPO_HARFBUZZ"; then
        do_pacman_install ragel
        do_uninstall include/harfbuzz "${_check[@]}" libharfbuzz{-subset,}.la
        extracommands=(-D{glib,gobject,cairo,icu,tests,introspection,docs,benchmark}"=disabled")
        [[ $ffmpeg = sharedlibs ]] && extracommands+=(--default-library=both)
        do_mesoninstall global "${extracommands[@]}"
        # directwrite shaper doesn't work with mingw headers, maybe too old
        [[ $ffmpeg = sharedlibs ]] && do_install "$LOCALDESTDIR"/bin-global/libharfbuzz-{subset-,}0.dll bin-video/
        do_checkIfExist
        unset extracommands
    fi

    _check=(libfribidi.a fribidi.pc)
    [[ $standalone = y ]] && _check+=(bin-video/fribidi.exe)
    [[ $ffmpeg = sharedlibs ]] && _check+=(bin-video/libfribidi-0.dll libfribidi.dll.a)
    if do_vcs "$SOURCE_REPO_FRIBIDI"; then
        do_patch "https://raw.githubusercontent.com/m-ab-s/mabs-patches/master/fribidi/0001-bin-only-use-vendored-getopt-if-not-provided.patch" am
        extracommands=("-Ddocs=false" "-Dtests=false")
        [[ $standalone = n ]] && extracommands+=("-Dbin=false")
        [[ $ffmpeg = sharedlibs ]] && extracommands+=(--default-library=both)
        do_mesoninstall video "${extracommands[@]}"
        do_checkIfExist
        unset extracommands
    fi

    _check=(ass/ass{,_types}.h libass.{{,l}a,pc})
    _deps=(lib{freetype,fontconfig,harfbuzz,fribidi}.a)
    [[ $ffmpeg = sharedlibs ]] && _check+=(bin-video/libass-9.dll libass.dll.a)
    if do_vcs "$SOURCE_REPO_LIBASS"; then
        do_autoreconf
        do_uninstall bin{,-video}/libass-9.dll libass.dll.a include/ass "${_check[@]}"
        extracommands=()
        enabled_any {lib,}fontconfig || extracommands+=(--disable-fontconfig)
        [[ $ffmpeg = sharedlibs ]] && extracommands+=(--disable-fontconfig --enable-shared)
        do_separate_confmakeinstall video "${extracommands[@]}"
        [[ $ffmpeg = sharedlibs ]] && do_install "$LOCALDESTDIR"/bin/libass-9.dll bin-video/
        do_checkIfExist
        unset extracommands
    fi
    if [[ $ffmpeg != sharedlibs && $ffmpeg != shared ]]; then
        _libs=(lib{freetype,harfbuzz{-subset,},fribidi,ass}.dll.a
            libav{codec,device,filter,format,util,resample}.dll.a
            lib{sw{scale,resample},postproc}.dll.a)
        for _lib in "${_libs[@]}"; do
            rm -f "$LOCALDESTDIR/lib/$_lib"
        done
        unset _lib _libs
    fi
fi

[[ $ffmpeg != no ]] && enabled gcrypt && do_pacman_install libgcrypt

if [[ $curl = y ]]; then
    enabled libtls && curl=libressl
    enabled openssl && curl=openssl
    enabled gnutls && curl=gnutls
    enabled mbedtls && curl=mbedtls
    [[ $curl = y ]] && curl=schannel
fi

if enabled_any gnutls librtmp || [[ $rtmpdump = y || $curl = gnutls ]]; then
    do_pacman_install nettle
    grep_and_sed '__declspec(__dllimport__)' "$MINGW_PREFIX"/include/gmp.h \\
        's|__declspec\\(__dllimport__\\)||g' "$MINGW_PREFIX"/include/gmp.h
    _check=(libgnutls.{,l}a gnutls.pc)
    _gnutls_ver=3.8.9
    _gnutls_hash=69e113d802d1670c4d5ac1b99040b1f2d5c7c05daec5003813c049b5184820ed
    if do_pkgConfig "gnutls = $_gnutls_ver" && do_wget -h $_gnutls_hash \\
        "https://www.gnupg.org/ftp/gcrypt/gnutls/v${_gnutls_ver%.*}/gnutls-${_gnutls_ver}.tar.xz"; then
        do_uninstall include/gnutls "${_check[@]}"
        grep_or_sed crypt32 lib/gnutls.pc.in 's/Libs.private.*/& -lcrypt32/'
        grep_and_sed tests src/gl/Makefile.am 's|(SUBDIRS.*) tests|\\1|'
        CFLAGS="-Wno-int-conversion" \\
            do_separate_confmakeinstall \\
            --disable-{cxx,doc,tools,tests,nls,rpath,libdane,guile,gcc-warnings} \\
            --without-{p11-kit,idn,tpm} --enable-local-libopts \\
            --with-included-unistring --disable-code-coverage \\
            LDFLAGS="$LDFLAGS -L${LOCALDESTDIR}/lib -L${MINGW_PREFIX}/lib"
        do_checkIfExist
    fi
fi

if [[ $curl = openssl ]] || { [[ $ffmpeg != no ]] && enabled openssl; }; then
    do_pacman_install openssl
fi
hide_libressl -R
if [[ $curl = libressl ]] || { [[ $ffmpeg != no ]] && enabled libtls; }; then
    _check=(tls.h lib{crypto,ssl,tls}.{pc,{,l}a} openssl.pc)
    [[ $standalone = y ]] && _check+=(bin-global/openssl.exe)
    if do_vcs "$SOURCE_REPO_LIBRESSL" libressl; then
        do_uninstall etc/ssl include/openssl "${_check[@]}"
        _sed="man"
        [[ $standalone = y ]] || _sed="apps tests $_sed"
        sed -ri "s;(^SUBDIRS .*) $_sed;\\1;" Makefile.am
        do_autogen
        do_separate_confmakeinstall global
        do_checkIfExist
        unset _sed
    fi
fi

{ enabled mbedtls || [[ $curl = mbedtls ]]; } && do_pacman_install mbedtls

if [[ $mediainfo = y || $bmx = y || $curl != n ]]; then
    do_pacman_install libunistring
    grep_and_sed dllimport "$MINGW_PREFIX"/include/unistring/woe32dll.h \\
        's|__declspec \\(dllimport\\)||g' "$MINGW_PREFIX"/include/unistring/woe32dll.h
    _deps=("$MINGW_PREFIX/lib/libunistring.a")
    _check=(libidn2.{{,l}a,pc} idn2.h)
    [[ $standalone == y ]] && _check+=(bin-global/idn2.exe)
    if do_pkgConfig "libidn2 = 2.3.8" &&
        do_wget -h f557911bf6171621e1f72ff35f5b1825bb35b52ed45325dcdee931e5d3c0787a \\
        "https://ftp.gnu.org/gnu/libidn/libidn2-2.3.8.tar.gz"; then
        do_uninstall "${_check[@]}"
        do_pacman_install gtk-doc
        [[ $standalone == y ]] || sed -ri 's|(bin_PROGRAMS = ).*|\\1|g' src/Makefile.am
        # unistring also depends on iconv
        grep_or_sed '@LTLIBUNISTRING@ @LTLIBICONV@' libidn2.pc.in \\
            's|(@LTLIBICONV@) (@LTLIBUNISTRING@)|\\2 \\1|'
        AUTOPOINT=true do_autoreconf
        do_separate_confmakeinstall global --disable-{doc,rpath,nls}
        do_checkIfExist
    fi
    _deps=(libidn2.a)
    _check=(libpsl.{{,l}a,h,pc})
    [[ $standalone == y ]] && _check+=(bin-global/psl.exe)
    if do_pkgConfig "libpsl = 0.21.5" &&
        do_wget -h 1dcc9ceae8b128f3c0b3f654decd0e1e891afc6ff81098f227ef260449dae208 \\
        "https://github.com/rockdaboot/libpsl/releases/download/0.21.5/libpsl-0.21.5.tar.gz"; then
        do_uninstall "${_check[@]}"
        [[ $standalone == y ]] || sed -ri 's|(bin_PROGRAMS = ).*|\\1|g' tools/Makefile.in
        grep_or_sed "Requires.private" libpsl.pc.in "/Libs:/ i\\Requires.private: libidn2"
        CFLAGS+=" -DPSL_STATIC" do_separate_confmakeinstall global --disable-{nls,rpath,gtk-doc-html,man,runtime}
        do_checkIfExist
    fi
fi

if [[ $mediainfo = y || $bmx = y || $curl != n || $cyanrip = y ]]; then
    do_pacman_install brotli nghttp2
    _check=(curl/curl.h libcurl.{{,l}a,pc})
    case $curl in
    libressl) _deps=(libssl.a) ;;
    openssl) _deps=("$MINGW_PREFIX/lib/libssl.a") ;;
    gnutls) _deps=(libgnutls.a) ;;
    mbedtls) _deps=("$MINGW_PREFIX/lib/libmbedtls.a") ;;
    *) _deps=() ;;
    esac
    [[ $standalone = y || $curl != n ]] && _check+=(bin-global/curl.exe)
    if do_vcs "$SOURCE_REPO_CURL"; then
        do_uninstall include/curl bin-global/curl-config "${_check[@]}"
        extra_opts=()
        case $curl in
        libressl|openssl)
            extra_opts+=(--with-{nghttp2,openssl} --without-{gnutls,mbedtls})
            ;;
        mbedtls) extra_opts+=(--with-{mbedtls,nghttp2} --without-openssl) ;;
        gnutls) extra_opts+=(--with-gnutls --without-{nghttp2,mbedtls,openssl}) ;;
        *) extra_opts+=(--with-{schannel,winidn,nghttp2} --without-{gnutls,mbedtls,openssl});;
        esac
       
        [[ ! -f configure || configure.ac -nt configure ]] &&
            do_autoreconf
        [[ $curl = openssl ]] && hide_libressl
        hide_conflicting_libs
        CPPFLAGS+=" -DGNUTLS_INTERNAL_BUILD -DNGHTTP2_STATICLIB -DPSL_STATIC" \\
            do_separate_confmakeinstall global "${extra_opts[@]}" \\
            --without-{libssh2,random,ca-bundle,ca-path,librtmp} \\
            --with-brotli --enable-sspi --disable-debug
        hide_conflicting_libs -R
        [[ $curl = openssl ]] && hide_libressl -R
        if [[ $curl != schannel ]]; then
            _notrequired=true
            cd_safe "build-$bits"
            PATH=/usr/bin log ca-bundle make ca-bundle
            unset _notrequired
            [[ -f lib/ca-bundle.crt ]] &&
                cp -f lib/ca-bundle.crt "$LOCALDESTDIR"/bin-global/curl-ca-bundle.crt
            cd_safe ..
        fi
        do_checkIfExist
    fi
fi

if [[ $exitearly = EE2 ]]; then
    do_simple_print -p '\\n\\t'"${orange}Exit due to env var MABS_EXIT_EARLY set to EE2"
    return
fi

if { { [[ $ffmpeg != no || $standalone = y ]] && enabled libtesseract; } ||
    { [[ $standalone = y ]] && enabled libwebp; }; }; then
    _check=(libglut.a glut.pc)
    if do_vcs "$SOURCE_REPO_LIBGLUT" freeglut; then
        do_uninstall lib/cmake/FreeGLUT include/GL "${_check[@]}"
        do_cmakeinstall -D{UNIX,FREEGLUT_BUILD_DEMOS,FREEGLUT_BUILD_SHARED_LIBS}=OFF -DFREEGLUT_REPLACE_GLUT=ON
        do_checkIfExist
    fi

    do_pacman_install libjpeg-turbo xz zlib zstd libdeflate
    _deps=(libglut.a "$zlib_dir"/lib/libz.a)
    _check=(libtiff.{a,-4.pc})
    [[ $standalone = y ]] && _check+=(bin-global/tiff{cp,dump,info,set,split}.exe)
    if do_vcs "$SOURCE_REPO_LIBTIFF"; then
        do_patch "https://raw.githubusercontent.com/m-ab-s/mabs-patches/master/libtiff/0001-tiffgt-Link-winmm-if-windows.patch" am
        do_patch "https://raw.githubusercontent.com/m-ab-s/mabs-patches/master/libtiff/0002-tiffgt-link-gl-after-glut.patch" am
        do_uninstall lib/cmake/tiff "${_check[@]}"
        extracommands=("-Dtiff-tests=OFF" "-Dtiff-docs=OFF")
        if [[ $standalone = y ]]; then
            extracommands+=("-Dtiff-tools=ON")
        else
            extracommands+=("-Dtiff-tools=OFF")
        fi
        grep_or_sed 'Requires.private' libtiff-4.pc.in \\
            '/Libs:/ a\\Requires.private: libjpeg liblzma zlib libzstd glut'
        CFLAGS+=" -DFREEGLUT_STATIC" \\
            do_cmakeinstall global -D{webp,jbig,lerc}=OFF "${extracommands[@]}"
        do_checkIfExist
        unset extracommands
    fi
fi

file_installed -s libtiff-4.pc &&
    grep_or_sed '\-ldeflate' "$(file_installed libtiff-4.pc)" \\
        's/Libs.private:.*/& -ldeflate/'

if [[ $ffmpeg != no || $standalone = y ]] && enabled libwebp; then
    do_pacman_install giflib
    _check=(libwebp{,mux}.{a,pc})
    [[ $standalone = y ]] && _check+=(libwebp{demux,decoder}.{a,pc}
    bin-global/{{c,d}webp,webpmux,img2webp}.exe)
    if do_vcs "$SOURCE_REPO_LIBWEBP"; then
        do_uninstall include/webp bin-global/gif2webp.exe "${_check[@]}"
        extracommands=("-DWEBP_BUILD_EXTRAS=OFF" "-DWEBP_BUILD_VWEBP=OFF")
        if [[ $standalone = y ]]; then
            extracommands+=(-DWEBP_BUILD_{{C,D,GIF2,IMG2}WEBP,ANIM_UTILS,WEBPMUX}"=ON")
        else
            extracommands+=(-DWEBP_BUILD_{{C,D,GIF2,IMG2,V}WEBP,ANIM_UTILS,WEBPMUX}"=OFF")
        fi
        CFLAGS+=" -DFREEGLUT_STATIC" \\
            do_cmakeinstall global -DWEBP_ENABLE_SWAP_16BIT_CSP=ON "${extracommands[@]}"
        do_checkIfExist
        unset extracommands
    fi
fi

if [[ $jpegxl = y ]] || { [[ $ffmpeg != no ]] && enabled libjxl; }; then
    _check=(bin/gflags_completions.sh gflags.pc gflags/gflags.h libgflags{,_nothreads}.a)
    if do_vcs "$SOURCE_REPO_GFLAGS"; then
        do_patch "https://raw.githubusercontent.com/m-ab-s/mabs-patches/master/gflags/0001-cmake-chop-off-.lib-extension-from-shlwapi.patch" am
        do_uninstall "${_check[@]}" lib/cmake/gflags include/gflags
        do_cmakeinstall -D{BUILD,INSTALL}_STATIC_LIBS=ON -DBUILD_gflags_LIB=ON -DINSTALL_HEADERS=ON \\
            -DREGISTER_{BUILD_DIR,INSTALL_PREFIX}=OFF
        do_checkIfExist
    fi

    do_pacman_install brotli lcms2
    _deps=(libgflags.a)
    _check=(libjxl{{,_threads}.a,.pc} jxl/decode.h)
    [[ $jpegxl = y ]] && _check+=(bin-global/{{c,d}jxl,jxlinfo}.exe)
    if do_vcs "$SOURCE_REPO_LIBJXL"; then
        do_git_submodule
        do_patch "https://raw.githubusercontent.com/m-ab-s/mabs-patches/master/libjxl/0001-brotli-link-enc-before-common.patch" am
        do_uninstall "${_check[@]}" include/jxl bin-global/cjpegli.exe bin-global/djpegli.exe 
        do_pacman_install asciidoc
        extracommands=()
        [[ $jpegxl = y ]] || extracommands=("-DJPEGXL_ENABLE_TOOLS=OFF")
        CXXFLAGS+=" -DJXL_CMS_STATIC_DEFINE -DJXL_STATIC_DEFINE -DJXL_THREADS_STATIC_DEFINE" \\
            do_cmakeinstall global -D{BUILD_TESTING,JPEGXL_ENABLE_{BENCHMARK,DOXYGEN,MANPAGES,OPENEXR,SKCMS,EXAMPLES,JPEGLI}}=OFF \\
            -DJPEGXL_{FORCE_SYSTEM_{BROTLI,LCMS2},STATIC}=ON "${extracommands[@]}"
        do_checkIfExist
        unset extracommands
    fi
fi

if files_exist bin-video/OpenCL.dll; then
    opencldll=$LOCALDESTDIR/bin-video/OpenCL.dll
else
    syspath=$(cygpath -S)
    [[ $bits = 32bit && -d $syspath/../SysWOW64 ]] && syspath+=/../SysWOW64
    opencldll=$syspath/OpenCL.dll
    unset syspath
fi
if [[ $ffmpeg != no && -f $opencldll ]] && enabled opencl; then
    do_simple_print "${orange}FFmpeg and related apps will depend on OpenCL.dll$reset"
    do_pacman_remove opencl-headers
    do_pacman_install tools-git
    _check=(CL/cl.h)
    if do_vcs "$SOURCE_REPO_OPENCLHEADERS"; then
        do_uninstall include/CL
        do_install CL/*.h include/CL/
        do_checkIfExist
    fi
    _check=(libOpenCL.a)
    if test_newer installed "$opencldll" "${_check[@]}"; then
        cd_safe "$LOCALBUILDDIR"
        [[ -d opencl ]] && rm -rf opencl
        mkdir -p opencl && cd_safe opencl
        create_build_dir
        gendef "$opencldll" >/dev/null 2>&1
        [[ -f OpenCL.def ]] && do_dlltool libOpenCL.a OpenCL.def
        [[ -f libOpenCL.a ]] && do_install libOpenCL.a
        do_checkIfExist
    fi
else
    do_removeOption --enable-opencl
fi
unset opencldll

if { [[ $ffmpeg != no || $standalone = y ]] && enabled libtesseract; } ||
    ! mpv_disabled libarchive; then
    do_pacman_install libarchive
    # need to fixup libarchive.pc
    grep_and_sed libiconv.dll.a "$MINGW_PREFIX/lib/pkgconfig/libarchive.pc" \\
        '/Libs/{
            s| -L'"${MINGW_PREFIX}"'/lib||g
            s|'"${MINGW_PREFIX}"'/lib/lib(.+)\\.dll\\.a|-l\\1|g
        }'
fi

if [[ $ffmpeg != no || $standalone = y ]] && enabled libtesseract; then
    do_pacman_remove tesseract-ocr
    _check=(libleptonica.{,l}a lept.pc)
    if do_vcs "$SOURCE_REPO_LEPT"; then
        do_uninstall include/leptonica "${_check[@]}"
        [[ -f configure ]] || do_autogen
        do_separate_confmakeinstall --disable-programs --without-{lib{openjpeg,webp},giflib}
        do_checkIfExist
    fi

    do_pacman_install pango asciidoc
    _check=(libtesseract.{,l}a tesseract.pc)
    if do_vcs "$SOURCE_REPO_TESSERACT"; then
        do_pacman_install docbook-xsl omp
        # Reverts a commit that breaks the pkgconfig file
        {
            git revert --no-edit b4a4f5c || git revert --abort
        } > /dev/null 2>&1
        do_autogen
        _check+=(bin-global/tesseract.exe)
        do_uninstall include/tesseract "${_check[@]}"
        sed -i 's|Requires.private.*|& libarchive iconv libtiff-4|' tesseract.pc.in
        grep_or_sed ws2_32 "$MINGW_PREFIX/lib/pkgconfig/libarchive.pc" 's;Libs.private:.*;& -lws2_32;g'
        case $CC in
        *clang) sed -i -e 's|Libs.private.*|& -fopenmp=libomp|' tesseract.pc.in ;;
        *) sed -i -e 's|Libs.private.*|& -fopenmp -lgomp|' tesseract.pc.in ;;
        esac
        do_separate_confmakeinstall global --disable-{graphics,tessdata-prefix} \\
            --without-curl \\
            LIBLEPT_HEADERSDIR="$LOCALDESTDIR/include" \\
            LIBS="$($PKG_CONFIG --libs iconv lept libtiff-4)" --datadir="$LOCALDESTDIR/bin-global"
        if [[ ! -f $LOCALDESTDIR/bin-global/tessdata/eng.traineddata ]]; then
            do_pacman_install tesseract-data-eng
            mkdir -p "$LOCALDESTDIR"/bin-global/tessdata
            do_install "$MINGW_PREFIX/share/tessdata/eng.traineddata" bin-global/tessdata/
            printf '%s\\n' \\
                "You can get more language data here:" \\
                "https://github.com/tesseract-ocr/tessdata" \\
                "Just download <lang you want>.traineddata and copy it to this directory." \\
                > "$LOCALDESTDIR"/bin-global/tessdata/need_more_languages.txt
        fi
        do_checkIfExist
    fi
fi

_check=(librubberband.a rubberband.pc rubberband/{rubberband-c,RubberBandStretcher}.h)
if { { [[ $ffmpeg != no ]] && enabled librubberband; } ||
    ! mpv_disabled rubberband; } &&
    do_vcs "$SOURCE_REPO_RUBBERBAND"; then
    do_uninstall "${_check[@]}"
    log "distclean" make distclean
    do_make PREFIX="$LOCALDESTDIR" install-static
    do_checkIfExist
fi

_check=(zimg{.h,++.hpp} libzimg.{,l}a zimg.pc)
if [[ $ffmpeg != no ]] && enabled libzimg &&
    do_vcs "$SOURCE_REPO_ZIMG"; then
    do_git_submodule
    do_uninstall "${_check[@]}"
    do_patch "https://raw.githubusercontent.com/m-ab-s/mabs-patches/master/zimg/0001-libm_wrapper-define-__CRT__NO_INLINE-before-math.h.patch" am
    do_autoreconf
    do_separate_confmakeinstall
    do_checkIfExist
fi

if [[ $exitearly = EE3 ]]; then
    do_simple_print -p '\\n\\t'"${orange}Exit due to env var MABS_EXIT_EARLY set to EE3"
    return
fi

set_title "compiling audio tools"
do_simple_print -p '\\n\\t'"${orange}Starting $bits compilation of audio tools${reset}"

if [[ $ffmpeg != no || $sox = y ]]; then
    do_pacman_install wavpack
    enabled_any libopencore-amr{wb,nb} && do_pacman_install opencore-amr
    if enabled libtwolame; then
        do_pacman_install twolame
        do_addOption --extra-cflags=-DLIBTWOLAME_STATIC
    fi
    enabled libmp3lame && do_pacman_install lame
fi

_check=(ilbc.h libilbc.{a,pc})
if [[ $ffmpeg != no ]] && enabled libilbc &&
    do_vcs "$SOURCE_REPO_LIBILBC"; then
    do_git_submodule
    do_uninstall "${_check[@]}"
    do_cmakeinstall -DUNIX=OFF
    do_checkIfExist
fi

_check=(libogg.{,l}a ogg/ogg.h ogg.pc)
if { [[ $flac = y ]] || enabled libvorbis; } &&
    do_vcs "$SOURCE_REPO_LIBOGG"; then
    do_uninstall include/ogg "${_check[@]}"
    do_autogen
    do_separate_confmakeinstall audio
    do_checkIfExist
fi

_check=(libvorbis{,enc,file}.{,l}a vorbis{,enc,file}.pc vorbis/vorbisenc.h)
if enabled libvorbis && do_vcs "$SOURCE_REPO_LIBVORBIS"; then
    do_uninstall include/vorbis "${_check[@]}"
    do_autogen
    do_separate_confmakeinstall audio --disable-docs
    do_checkIfExist
fi

_check=(libspeex.{,l}a speex.pc speex/speex.h)
[[ $standalone = y ]] && _check+=(bin-audio/speex{enc,dec}.exe)
if enabled libspeex && do_vcs "$SOURCE_REPO_SPEEX"; then
    do_pacman_remove speex
    do_uninstall include/speex "${_check[@]}"
    do_autogen
    extracommands=()
    [[ $standalone = y ]] || extracommands+=(--disable-binaries)
    do_separate_confmakeinstall audio --enable-vorbis-psy "${extracommands[@]}"
    do_checkIfExist
    unset extracommands
fi

_check=(libFLAC{,++}.a flac{,++}.pc)
[[ $standalone = y ]] && _check+=(bin-audio/flac.exe)
if [[ $flac = y ]]; then
    if do_vcs "$SOURCE_REPO_FLAC"; then
        if [[ $standalone = y ]]; then
            _check+=(bin-audio/metaflac.exe)
        fi
        do_uninstall include/FLAC{,++} share/aclocal/libFLAC{,++}.m4 "${_check[@]}"
        do_cmakeinstall audio -DBUILD_{DOCS,DOXYGEN,EXAMPLES,TESTING}=OFF -DINSTALL_MANPAGES=OFF
        do_checkIfExist
    fi
elif [[ $sox = y ]] || { [[ $standalone = y ]] && enabled_any libvorbis libopus; }; then
    do_pacman_install flac
    grep_and_sed dllimport "$MINGW_PREFIX"/include/FLAC++/export.h \\
        's|__declspec\\(dllimport\\)||g' "$MINGW_PREFIX"/include/FLAC{,++}/export.h
fi
grep_and_sed dllimport "$LOCALDESTDIR"/include/FLAC++/export.h \\
        's|__declspec\\(dllimport\\)||g' "$LOCALDESTDIR"/include/FLAC{,++}/export.h
grep_or_sed pthread "$LOCALDESTDIR/lib/pkgconfig/flac.pc" 's/Libs.private: /&-pthread /;s/Cflags: .*/& -pthread/'

_check=(libvo-amrwbenc.{,l}a vo-amrwbenc.pc)
if [[ $ffmpeg != no ]] && enabled libvo-amrwbenc &&
    do_pkgConfig "vo-amrwbenc = 0.1.3" &&
    do_wget_sf -h f63bb92bde0b1583cb3cb344c12922e0 \\
        "opencore-amr/vo-amrwbenc/vo-amrwbenc-0.1.3.tar.gz"; then
    do_uninstall include/vo-amrwbenc "${_check[@]}"
    do_separate_confmakeinstall
    do_checkIfExist
fi

if { [[ $ffmpeg != no ]] && enabled libfdk-aac; } || [[ $fdkaac = y ]]; then
    _check=(libfdk-aac.{,l}a fdk-aac.pc)
    if do_vcs "$SOURCE_REPO_FDKAAC"; then
        do_autoreconf
        do_uninstall include/fdk-aac "${_check[@]}"
        CXXFLAGS+=" -fno-exceptions -fno-rtti" do_separate_confmakeinstall
        do_checkIfExist
    fi
    _check=(bin-audio/fdkaac.exe)
    _deps=(libfdk-aac.a)
    if [[ $standalone = y ]] &&
        do_vcs "$SOURCE_REPO_FDKAACEXE" bin-fdk-aac; then
        do_autoreconf
        do_uninstall "${_check[@]}"
        CFLAGS+=" $($PKG_CONFIG --cflags fdk-aac)" \\
        LDFLAGS+=" $($PKG_CONFIG --cflags --libs fdk-aac)" \\
            do_separate_confmakeinstall audio
        do_checkIfExist
    fi
fi

if [[ $faac = y ]]; then
    _check=(bin-audio/faac.exe)
    if ! [[ $standalone = y ]]; then
        do_pacman_install faac
    elif do_vcs "$SOURCE_REPO_FAAC"; then
        do_pacman_remove faac
        do_uninstall libfaac.a faac{,cfg}.h "${_check[@]}"
        log bootstrap ./bootstrap
        do_separate_confmakeinstall audio
        do_checkIfExist
    fi
fi

_check=(bin-audio/exhale.exe)
if [[ $exhale = y ]] &&
    do_vcs "$SOURCE_REPO_EXHALE"; then
    do_uninstall "${_check[@]}"
    _notrequired=true
    do_cmakeinstall audio
    do_checkIfExist
    unset _notrequired
fi

_check=(bin-audio/ogg{enc,dec}.exe)
_deps=(ogg.pc vorbis.pc)
if [[ $standalone = y ]] && enabled libvorbis &&
    do_vcs "$SOURCE_REPO_VORBIS_TOOLS"; then
    do_patch "https://raw.githubusercontent.com/m-ab-s/mabs-patches/master/vorbis-tools/0001-utf8-add-empty-convert_free_charset-for-Windows.patch" am
    do_patch "https://raw.githubusercontent.com/m-ab-s/mabs-patches/master/vorbis-tools/0002-getopt-just-remove-it.patch" am
    do_autoreconf
    do_uninstall "${_check[@]}"
    extracommands=()
    enabled libspeex || extracommands+=(--without-speex)
    do_separate_conf --disable-{ogg123,vorbiscomment,vcut,ogginfo} \\
        --with-lib{iconv,intl}-prefix="$MINGW_PREFIX" "${extracommands[@]}"
    do_make
    do_install oggenc/oggenc.exe oggdec/oggdec.exe bin-audio/
    do_checkIfExist
    unset extracommands
fi

_check=(libopus.{,l}a opus.pc opus/opus.h)
if enabled libopus && do_vcs "$SOURCE_REPO_OPUS"; then
    do_pacman_remove opus
    do_uninstall include/opus "${_check[@]}"
    (
        sha=$(grep dnn/download_model.sh autogen.sh | awk -F'"' '{print $2}')
        model=opus_data-${sha}.tar.gz
        pushd . > /dev/null
        [ -f "$LOCALBUILDDIR/$model" ] || do_wget -r -q -n "https://media.xiph.org/opus/models/$model"
        popd > /dev/null || return 1
        ln -s "$LOCALBUILDDIR/$model" .
    )
    do_autogen
    do_separate_confmakeinstall --disable-{stack-protector,doc,extra-programs}
    do_checkIfExist
fi

if [[ $standalone = y ]] && enabled libopus; then
    do_pacman_install openssl
    hide_libressl
    do_pacman_remove opusfile
    _check=(opus/opusfile.h libopus{file,url}.{,l}a opus{file,url}.pc)
    _deps=(ogg.pc opus.pc "$MINGW_PREFIX"/lib/pkgconfig/libssl.pc)
    if do_vcs "$SOURCE_REPO_OPUSFILE"; then
        do_uninstall "${_check[@]}"
        do_patch "https://raw.githubusercontent.com/m-ab-s/mabs-patches/master/opusfile/0001-Disable-cert-store-integration-if-OPENSSL_VERSION_NU.patch" am
        do_patch "https://raw.githubusercontent.com/m-ab-s/mabs-patches/master/opusfile/0002-configure-Only-add-std-c89-if-not-mingw-because-of-c.patch" am
        do_autogen
        do_separate_confmakeinstall --disable-{examples,doc}
        do_checkIfExist
    fi

    _check=(opus/opusenc.h libopusenc.{pc,{,l}a})
    _deps=(opus.pc)
    if do_vcs "$SOURCE_REPO_LIBOPUSENC"; then
        do_uninstall "${_check[@]}"
        do_autogen
        do_separate_confmakeinstall --disable-{examples,doc}
        do_checkIfExist
    fi

    _check=(bin-audio/opusenc.exe)
    _deps=(opusfile.pc libopusenc.pc)
    if do_vcs "$SOURCE_REPO_OPUSEXE"; then
        _check+=(bin-audio/opus{dec,info}.exe)
        do_uninstall "${_check[@]}"
        do_autogen
        do_separate_confmakeinstall audio
        do_checkIfExist
    fi
    hide_libressl -R
fi

_check=(soxr.h libsoxr.a)
if [[ $ffmpeg != no ]] && enabled libsoxr &&
    do_vcs "$SOURCE_REPO_LIBSOXR"; then
    do_uninstall "${_check[@]}"
    do_cmakeinstall -D{WITH_LSR_BINDINGS,BUILD_TESTS,WITH_OPENMP}=off
    do_checkIfExist
fi

_check=(libcodec2.a codec2.pc codec2/codec2.h)
if [[ $ffmpeg != no ]] && enabled libcodec2; then
    if do_vcs "$SOURCE_REPO_CODEC2"; then
        do_uninstall all include/codec2 "${_check[@]}"
        sed -i 's|if(WIN32)|if(FALSE)|g' CMakeLists.txt
        if enabled libspeex; then
            # rename same-named symbols copied from speex
            grep -ERl "\b(lsp|lpc)_to_(lpc|lsp)" --include="*.[ch]" | \
                xargs -r sed -ri "s;((lsp|lpc)_to_(lpc|lsp));c2_\1;g"
        fi
        do_cmakeinstall -D{UNITTEST,INSTALL_EXAMPLES}=off \
            -DCMAKE_INSTALL_BINDIR="$(pwd)/build-$bits/_bin"
        do_checkIfExist
    fi
fi

if [[ $standalone = y ]] && enabled libmp3lame; then
    _check=(bin-audio/lame.exe)
    if files_exist "${_check[@]}" &&
        grep -q "3.100" "$LOCALDESTDIR/bin-audio/lame.exe"; then
        do_print_status "lame 3.100" "$green" "Up-to-date"
    elif do_wget_sf \
            -h ddfe36cab873794038ae2c1210557ad34857a4b6bdc515785d1da9e175b1da1e \
            "lame/lame/3.100/lame-3.100.tar.gz"; then
        do_uninstall include/lame libmp3lame.{,l}a "${_check[@]}"
        _mingw_patches_lame="https://raw.githubusercontent.com/Alexpux/MINGW-packages/master/mingw-w64-lame"
        do_patch "$_mingw_patches_lame/0005-no-gtk.all.patch"
        do_patch "$_mingw_patches_lame/0006-dont-use-outdated-symbol-list.patch"
        do_patch "$_mingw_patches_lame/0007-revert-posix-code.patch"
        do_patch "$_mingw_patches_lame/0008-skip-termcap.patch"
        do_patch "https://raw.githubusercontent.com/m-ab-s/mabs-patches/master/lame/0001-libmp3lame-vector-Makefile.am-Add-msse-to-fix-i686-c.patch"
        do_autoreconf
        do_separate_conf --enable-nasm
        do_make
        do_install frontend/lame.exe bin-audio/
        do_checkIfExist
        unset _mingw_patches_lame
    fi
fi

_check=(libgme.{a,pc})
if [[ $ffmpeg != no ]] && enabled libgme && do_pkgConfig "libgme = 0.6.3" &&
    do_wget -h aba34e53ef0ec6a34b58b84e28bf8cfbccee6585cebca25333604c35db3e051d \
        "https://bitbucket.org/mpyne/game-music-emu/downloads/game-music-emu-0.6.3.tar.xz"; then
    do_uninstall include/gme "${_check[@]}"
    do_cmakeinstall -DENABLE_UBSAN=OFF
    do_checkIfExist
fi

_check=(libbs2b.{{,l}a,pc})
if [[ $ffmpeg != no ]] && enabled libbs2b && do_pkgConfig "libbs2b = 3.1.0" &&
    do_wget_sf -h c1486531d9e23cf34a1892ec8d8bfc06 "bs2b/libbs2b/3.1.0/libbs2b-3.1.0.tar.bz2"; then
    do_uninstall include/bs2b "${_check[@]}"
    # sndfile check is disabled since we don't compile binaries anyway
    grep -q sndfile configure && sed -i '20119,20133d' configure
    sed -i "s|bin_PROGRAMS = .*||" src/Makefile.in
    do_separate_confmakeinstall
    do_checkIfExist
fi

_check=(libsndfile.a sndfile.{h,pc})
if [[ $sox = y ]] && do_vcs "$SOURCE_REPO_SNDFILE" sndfile; then
    do_uninstall include/sndfile.hh "${_check[@]}"
    do_cmakeinstall -DBUILD_EXAMPLES=off -DBUILD_TESTING=off -DBUILD_PROGRAMS=OFF
    do_checkIfExist
fi

_check=(bin-audio/sox.exe sox.pc)
_deps=(libsndfile.a opus.pc "$MINGW_PREFIX"/lib/libmp3lame.a)
if [[ $sox = y ]]; then
    do_pacman_install libmad
    extracommands=()
    if enabled libopus; then
        [[ $standalone = y ]] || do_pacman_install opusfile
    else
        extracommands+=(--without-opus)
    fi
    if do_vcs "$SOURCE_REPO_SOX" sox; then
        do_patch "https://raw.githubusercontent.com/m-ab-s/mabs-patches/master/sox/0001-sox_version-fold-function-into-sox_version_info.patch" am
        do_patch "https://raw.githubusercontent.com/msys2/MINGW-packages/master/mingw-w64-sox/0001-ucrt-no-rewind-pipe.patch"
        do_uninstall sox.{pc,h} bin-audio/{soxi,play,rec}.exe libsox.{,l}a "${_check[@]}"
        do_autoreconf
        extralibs=(-lshlwapi -lz)
        enabled libmp3lame || extracommands+=(--without-lame)
        enabled_any libopencore-amr{wb,nb} &&
            extralibs+=(-lvo-amrwbenc) ||
            extracommands+=(--without-amr{wb,nb})
        enabled libtwolame &&
            extracommands+=(CFLAGS="$CFLAGS -DLIBTWOLAME_STATIC") ||
            extracommands+=(--without-twolame)
        enabled libvorbis || extracommands+=(--without-oggvorbis)
        hide_conflicting_libs
        sed -i 's|found_libgsm=yes|found_libgsm=no|g' configure
        do_separate_conf --disable-symlinks LIBS="-L$LOCALDESTDIR/lib ${extralibs[*]}" "${extracommands[@]}"
        do_make
        do_install src/sox.exe bin-audio/
        do_install sox.pc
        hide_conflicting_libs -R
        do_checkIfExist
        unset extralibs
    fi
    unset extracommands
fi

_check=(libopenmpt.{a,pc})
if [[ $ffmpeg != no ]] && enabled libopenmpt &&
    do_vcs "$SOURCE_REPO_LIBOPENMPT"; then
    do_uninstall include/libopenmpt "${_check[@]}"
    mkdir bin 2> /dev/null
    extracommands=("CONFIG=mingw64-win${bits%bit}" "AR=ar" "STATIC_LIB=1" "SHARED_LIB=0" "EXAMPLES=0" "OPENMPT123=0"
        "TEST=0" "OS=" "CC=$CC" "CXX=$CXX" "MINGW_COMPILER=${CC##* }")
    log clean make clean "${extracommands[@]}"
    do_makeinstall PREFIX="$LOCALDESTDIR" "${extracommands[@]}"
    sed -i 's/Libs.private.*/& -lrpcrt4/' "$LOCALDESTDIR/lib/pkgconfig/libopenmpt.pc"
    do_checkIfExist
    unset extracommands
fi

_check=(libmysofa.{a,pc} mysofa.h)
if [[ $ffmpeg != no ]] && enabled libmysofa &&
    do_vcs "$SOURCE_REPO_LIBMYSOFA"; then
    do_uninstall "${_check[@]}"
    do_cmakeinstall -DBUILD_TESTS=no -DCODE_COVERAGE=OFF
    do_checkIfExist
fi

_check=(libflite.a flite/flite.h)
if enabled libflite && do_vcs "$SOURCE_REPO_FLITE"; then
    do_patch "https://raw.githubusercontent.com/m-ab-s/mabs-patches/master/flite/0001-tools-find_sts_main.c-Include-windows.h-before-defin.patch" am
    do_uninstall libflite_cmu_{grapheme,indic}_{lang,lex}.a \
        libflite_cmu_us_{awb,kal,kal16,rms,slt}.a \
        libflite_{cmulex,usenglish,cmu_time_awb}.a "${_check[@]}" include/flite
    log clean make clean
    do_configure --bindir="$LOCALDESTDIR"/bin-audio --disable-shared \
        --with-audio=none
    do_make && do_makeinstall
    do_checkIfExist
fi

_check=(shine/layer3.h libshine.{,l}a shine.pc)
[[ $standalone = y ]] && _check+=(bin-audio/shineenc.exe)
if enabled libshine && do_vcs "$SOURCE_REPO_SHINE"; then
    do_uninstall "${_check[@]}"
    [[ $standalone = n ]] && sed -i '/bin_PROGRAMS/,+4d' Makefile.am
    # fix out-of-root build
    # shellcheck disable=SC2016
    sed -ri -e 's;(libshine.sym)$;$(srcdir)/\1;' \
        -e '/libshine_la_HEADERS/{s;(src/lib);$(srcdir)/\1;}' \
        -e '/shineenc_CFLAGS/{s;(src/lib);$(srcdir)/\1;}' Makefile.am
    rm configure
    do_autoreconf
    do_separate_confmakeinstall audio
    do_checkIfExist
fi

_check=(openal.pc libopenal.a)
if { { [[ $ffmpeg != no ]] &&
    enabled openal; } || mpv_enabled openal; } &&
    do_vcs "$SOURCE_REPO_OPENAL"; then
    do_uninstall "${_check[@]}"
    do_patch "https://raw.githubusercontent.com/m-ab-s/mabs-patches/master/openal-soft/0001-CMake-Fix-issues-for-mingw-w64.patch" am
    CC=${CC/ccache /}.bat CXX=${CXX/ccache /}.bat \
        do_cmakeinstall -DLIBTYPE=STATIC -DALSOFT_UTILS=OFF -DALSOFT_EXAMPLES=OFF
    sed -i 's/Libs.private.*/& -luuid -lole32/' "$LOCALDESTDIR/lib/pkgconfig/openal.pc" # uuid is for FOLDERID_* stuff
    do_checkIfExist
    unset _mingw_patches
fi

_check=(liblc3.a lc3.pc)
if [[ $ffmpeg != no ]] && enabled liblc3 &&
    do_vcs "$SOURCE_REPO_LIBLC3"; then
    do_uninstall "${_check[@]}"
    if [[ $standalone = y ]]; then
        _check+=(bin-audio/{d,e}lc3.exe)
        LDFLAGS+=" -lpthread" do_mesoninstall audio -Dtools=true
    else
        do_mesoninstall audio
    fi
    do_checkIfExist
fi

_check=(bin/atw_ldwrapper libAudioToolboxWrapper.a)
if [[ $ffmpeg != no ]] && enabled audiotoolbox; then
    _qtfiles_url="https://github.com/AnimMouse/QTFiles/releases/download/v12.10.11"
    _deps=(bin-video/{ASL,CoreAudioToolbox,CoreFoundation,icudt62,libdispatch,libicuin,libicuuc,objc}.dll)
    if ! files_exist "${_deps[@]}"; then
        if [[ $build64 = yes ]]; then
            do_wget -r -q -h 32fcd058936410f7eabd3b55a8931bce5f45bb7892d6a2c65387820daca52f58 \
                "${_qtfiles_url}/QTfiles64.7z"
            do_install *.dll bin-video
            rm -rf ../QTfiles64/
        fi
        if [[ $build32 = yes ]]; then
            do_wget -r -q -h c6c582fe1af4e0c2b1eb7c141ad929a81f14d123aedd3b16df8226c104fb3028 \
                "${_qtfiles_url}/QTfiles.7z"
            do_install *.dll bin-video
            rm -rf ../QTfiles/
        fi
    fi

    if do_vcs "$SOURCE_REPO_AUDIOTOOLBOX"; then
        do_uninstall "${_check[@]}"
        do_cmakeinstall
        do_checkIfExist
    fi
    unset _qtfiles_url
fi

if [[ $exitearly = EE4 ]]; then
    do_simple_print -p '\n\t'"${orange}Exit due to env var MABS_EXIT_EARLY set to EE4"
    return
fi

set_title "compiling video tools"
do_simple_print -p '\n\t'"${orange}Starting $bits compilation of video tools${reset}"

_deps=(gnutls.pc)
_check=(librtmp.{a,pc})
[[ $rtmpdump = y || $standalone = y ]] && _check+=(bin-video/rtmpdump.exe)
if { [[ $rtmpdump = y ]] ||
    { [[ $ffmpeg != no ]] && enabled librtmp; }; } &&
    do_vcs "$SOURCE_REPO_LIBRTMP" librtmp; then
    [[ $rtmpdump = y || $standalone = y ]] && _check+=(bin-video/rtmp{suck,srv,gw}.exe)
    do_uninstall include/librtmp "${_check[@]}"
    [[ -f librtmp/librtmp.a ]] && log "clean" make clean

    _rtmp_pkgver() {
        printf '%s-%s-%s_%s-%s-static' \
            "$(grep -oP "(?<=^VERSION=).+" Makefile)" \
            "$(git log -1 --format=format:%cd-g%h --date=format:%Y%m%d)" \
            "GnuTLS" \
            "$($PKG_CONFIG --modversion gnutls)" \
            "$CARCH"
    }
    do_makeinstall XCFLAGS="$CFLAGS -I$MINGW_PREFIX/include" XLDFLAGS="$LDFLAGS" SHARED= \
        SYS=mingw prefix="$LOCALDESTDIR" bindir="$LOCALDESTDIR"/bin-video \
        sbindir="$LOCALDESTDIR"/bin-video mandir="$LOCALDESTDIR"/share/man \
        CRYPTO=GNUTLS LIB_GNUTLS="$($PKG_CONFIG --libs gnutls) -lz" \
        VERSION="$(_rtmp_pkgver)"
    do_checkIfExist
    unset _rtmp_pkgver
fi

_check=(libvpx.a vpx.pc)
[[ $standalone = y || $av1an != n ]] && _check+=(bin-video/vpxenc.exe)
if { enabled libvpx || [[ $vpx = y ]]; } && do_vcs "$SOURCE_REPO_VPX" vpx; then
    do_pacman_install yasm
    extracommands=()
    [[ -f config.mk ]] && log "distclean" make distclean
    [[ $standalone = y || $av1an != n ]] && _check+=(bin-video/vpxdec.exe) ||
        extracommands+=(--disable-{examples,webm-io,libyuv,postproc})
    do_uninstall include/vpx "${_check[@]}"
    # Work around for semaphore.h not having struct _timespec64 info
    grep_or_sed sys/timeb.h vp8/common/threading.h \
        '/<semaphore.h>/ i\#include <sys/timeb.h>'
    create_build_dir
    [[ $bits = 32bit ]] && arch=x86 || arch=x86_64
    [[ $ffmpeg = sharedlibs ]] || extracommands+=(--enable-{vp9-postproc,vp9-highbitdepth})
    get_external_opts extracommands
    config_path=.. do_configure --target="${arch}-win${bits%bit}-gcc" \
        --disable-{shared,unit-tests,docs,install-bins} \
        "${extracommands[@]}"
    sed -i 's;HAVE_GNU_STRIP=yes;HAVE_GNU_STRIP=no;' -- ./*.mk
    do_make
    do_makeinstall
    [[ $standalone = y || $av1an != n ]] && do_install vpx{enc,dec}.exe bin-video/
    do_checkIfExist
    unset extracommands
else
    pc_exists vpx || do_removeOption --enable-libvpx
fi

_check=(libvmaf.{a,pc} libvmaf/libvmaf.h)
if [[ $ffmpeg != no ]] && enabled libvmaf &&
    do_vcs "$SOURCE_REPO_LIBVMAF"; then
    do_uninstall share/model "${_check[@]}"
    do_pacman_install -m vim # for built_in_models
    cd_safe libvmaf
    CFLAGS="-msse2 -mfpmath=sse -mstackrealign $CFLAGS" do_mesoninstall video \
        -Denable_float=true -Dbuilt_in_models=true -Denable_tests=false
    do_checkIfExist
fi
file_installed -s libvmaf.dll.a && rm "$(file_installed libvmaf.dll.a)"

_check=(libaom.a aom.pc)
[[ $aom = y || $standalone = y || $av1an != n ]] && _check+=(bin-video/aom{dec,enc}.exe)
if { [[ $aom = y ]] || [[ $libavif = y ]] || { [[ $ffmpeg != no ]] && enabled libaom; }; } &&
    do_vcs "$SOURCE_REPO_LIBAOM"; then
    do_pacman_install yasm
    extracommands=()
    if [[ $aom = y || $standalone = y || $av1an != n ]]; then
        # fix google's shit
        sed -ri 's;_PREFIX.+CMAKE_INSTALL_BINDIR;_FULL_BINDIR;' \
            build/cmake/aom_install.cmake
    else
        extracommands+=("-DENABLE_EXAMPLES=off")
    fi
    do_uninstall include/aom "${_check[@]}"
    get_external_opts extracommands
    do_cmakeinstall video -DENABLE_{DOCS,TOOLS,TEST{S,DATA}}=off \
        -DENABLE_NASM=on -DFORCE_HIGHBITDEPTH_DECODING=0 "${extracommands[@]}"
    do_checkIfExist
    unset extracommands
fi

_check=(dav1d/dav1d.h dav1d.pc libdav1d.a)
[[ $standalone = y ]] && _check+=(bin-video/dav1d.exe)
if { [[ $dav1d = y ]] || [[ $libavif = y ]] || { [[ $ffmpeg != no ]] && enabled libdav1d; }; } &&
    do_vcs "$SOURCE_REPO_DAV1D"; then
    do_uninstall include/dav1d "${_check[@]}"
    extracommands=()
    [[ $standalone = y ]] || extracommands=("-Denable_tools=false")
    do_mesoninstall video -Denable_{tests,examples}=false "${extracommands[@]}"
    do_checkIfExist
    unset extracommands
fi

_check=()
{ [[ $rav1e = y ]] || [[ $av1an != n ]] ||
    { enabled librav1e && [[ $standalone = y ]]; } } &&
    _check+=(bin-video/rav1e.exe)
{ enabled librav1e || [[ $libavif = y ]]; } && _check+=(librav1e.a rav1e.pc rav1e/rav1e.h)
if { [[ $rav1e = y ]] || [[ $libavif = y ]] || enabled librav1e; } &&
    do_vcs "$SOURCE_REPO_LIBRAV1E"; then
    do_uninstall "${_check[@]}" include/rav1e

    # We want to hide libgit2 unless we have a static library
    _libgit2_pc="$MINGW_PREFIX/lib/pkgconfig/libgit2.pc"
    if ! [[ -f $MINGW_PREFIX/lib/libgit2.a ]]; then
        if  [[ -f $_libgit2_pc ]]; then
            mv -f "$_libgit2_pc"{,.dyn}
        fi
    else
        if ! [[ -f $_libgit2_pc ]]; then
            cp -f "$_libgit2_pc"{.dyn,}
        fi
    fi
    unset _libgit2_pc

    # standalone binary
    if [[ $rav1e = y || $standalone = y || $av1an != n ]]; then
        do_rust --profile release-no-lto
        find "target/$CARCH-pc-windows-gnu$rust_target_suffix" -name "rav1e.exe" | while read -r f; do
            do_install "$f" bin-video/
        done
    fi

    # C lib
    if [[ $libavif = y ]] || enabled librav1e; then
        rm -f "$CARGO_HOME/config" 2> /dev/null
        PKG_CONFIG="$LOCALDESTDIR/bin/ab-pkg-config-static.bat" \
            log "install-rav1e-c" cargo capi install \
            --release --jobs "$cpuCount" --prefix="$LOCALDESTDIR" \
            --destdir="$PWD/install-$bits"

        # do_install "install-$bits/bin/rav1e.dll" bin-video/
        # do_install "install-$bits/lib/librav1e.dll.a" lib/
        do_install "$(find "install-$bits/" -name "librav1e.a")" lib/
        do_install "$(find "install-$bits/" -name "rav1e.pc")" lib/pkgconfig/
        sed -i 's/\\/\//g' "$LOCALDESTDIR/lib/pkgconfig/rav1e.pc" >/dev/null 2>&1
        do_install "$(find "install-$bits/" -name "rav1e")"/*.h include/rav1e/
    fi

    do_checkIfExist
fi
# add allow-multiple-definition to the .pc file to fix linking with other rust libraries
sed -i 's/Libs.private:.*/& -Wl,--allow-multiple-definition/' "$LOCALDESTDIR/lib/pkgconfig/rav1e.pc" >/dev/null 2>&1

_check=(bin-video/SvtAv1EncApp.exe
    libSvtAv1Enc.a SvtAv1Enc.pc)
if [[ $bits = 32bit ]]; then
    do_removeOption --enable-libsvtav1
elif { [[ $svtav1 = y ]] || enabled libsvtav1; } &&
    do_vcs "$SOURCE_REPO_SVTAV1"; then
    do_uninstall include/svt-av1 "${_check[@]}" include/svt-av1
    do_cmakeinstall video -DUNIX=OFF -DENABLE_AVX512=ON
    do_checkIfExist
fi

if [[ $libavif = y ]]; then
    do_pacman_install libjpeg-turbo libyuv
    _check=(libavif.{a,pc} avif/avif.h)
    [[ $standalone = y ]] && _check+=(bin-video/avif{enc,dec}.exe)
    if { pc_exists "aom" || pc_exists "dav1d" || pc_exists "rav1e" || pc_exists "SvtAv1Enc"; } &&
        do_vcs "$SOURCE_REPO_LIBAVIF"; then
        # chop off any .lib suffixes that is attached to a library name
        grep_and_sed '\.lib' CMakeLists.txt 's|(\w)\.lib\b|\1|g'
        do_uninstall "${_check[@]}"
        extracommands=()
        pc_exists "dav1d" && extracommands+=("-DAVIF_CODEC_DAV1D=SYSTEM")
        pc_exists "rav1e" && extracommands+=("-DAVIF_CODEC_RAV1E=SYSTEM")
        pc_exists "aom" && extracommands+=("-DAVIF_CODEC_AOM=SYSTEM")
        pc_exists "SvtAv1Enc" && extracommands+=("-DAVIF_CODEC_SVT=SYSTEM")
        case $standalone in
        y) extracommands+=("-DAVIF_BUILD_APPS=ON") ;;
        *) extracommands+=("-DAVIF_BUILD_APPS=OFF") ;;
        esac
        do_cmakeinstall video -DAVIF_ENABLE_WERROR=OFF "${extracommands[@]}"
        do_checkIfExist
        unset extracommands
    fi
fi

_check=(libkvazaar.{,l}a kvazaar.pc kvazaar.h)
[[ $standalone = y ]] && _check+=(bin-video/kvazaar.exe)
if { [[ $other265 = y ]] || { [[ $ffmpeg != no ]] && enabled libkvazaar; }; } &&
    do_vcs "$SOURCE_REPO_LIBKVAZAAR"; then
    do_patch "https://github.com/m-ab-s/mabs-patches/raw/master/kvazaar/0001-Mingw-w64-Re-enable-avx2.patch" am
    do_uninstall kvazaar_version.h "${_check[@]}"
    do_autogen
    [[ $standalone = y || $other265 = y ]] ||
        sed -i "s|bin_PROGRAMS = .*||" src/Makefile.in
    CFLAGS+=" -fno-asynchronous-unwind-tables -DKVZ_BIT_DEPTH=10" \\
        do_separate_confmakeinstall video
    do_checkIfExist
fi

_check=(libSDL2{,_test,main}.a sdl2.pc SDL2/SDL.h)
if { { [[ $ffmpeg != no ]] &&
    { enabled sdl2 || ! disabled_any sdl2 autodetect; }; } ||
    mpv_enabled sdl2; } &&
    do_vcs "$SOURCE_REPO_SDL2"; then
    do_uninstall include/SDL2 lib/cmake/SDL2 bin/sdl2-config "${_check[@]}"
    do_autogen
    sed -i 's|__declspec(dllexport)||g' include/{begin_code,SDL_opengl}.h
    do_separate_confmakeinstall
    do_checkIfExist
fi

_check=(libdvdread.{,l}a dvdread.pc)
if { { [[ $ffmpeg != no ]] && enabled_any libdvdread libdvdnav; } ||
    [[ $mplayer = y ]] || mpv_enabled dvdnav; } &&
    do_vcs "$SOURCE_REPO_LIBDVDREAD" dvdread; then
    do_autoreconf
    do_uninstall include/dvdread "${_check[@]}"
    do_separate_confmakeinstall
    do_checkIfExist
fi
[[ -f $LOCALDESTDIR/lib/pkgconfig/dvdread.pc ]] &&
    grep_or_sed "Libs.private" "$LOCALDESTDIR"/lib/pkgconfig/dvdread.pc \
        "/Libs:/ a\Libs.private: -ldl -lpsapi"

_check=(libdvdnav.{,l}a dvdnav.pc)
_deps=(libdvdread.a)
if { { [[ $ffmpeg != no ]] && enabled libdvdnav; } ||
    [[ $mplayer = y ]] || mpv_enabled dvdnav; } &&
    do_vcs "$SOURCE_REPO_LIBDVDNAV" dvdnav; then
    do_autoreconf
    do_uninstall include/dvdnav "${_check[@]}"
    do_separate_confmakeinstall
    do_checkIfExist
fi

if { [[ $ffmpeg != no ]] && enabled_any gcrypt libbluray; } ||
    ! mpv_disabled libbluray; then
    do_pacman_install libgcrypt
    grep_or_sed ws2_32 "$MINGW_PREFIX/bin/libgcrypt-config" 's;-lgpg-error;& -lws2_32;'
    grep_or_sed ws2_32 "$MINGW_PREFIX/bin/gpg-error-config" 's;-lgpg-error;& -lws2_32;'
fi

if { [[ $ffmpeg != no ]] && enabled libbluray; } || ! mpv_disabled libbluray; then
    _check=(bin-video/libaacs.dll libaacs.{{,l}a,pc} libaacs/aacs.h)
    if do_vcs "$SOURCE_REPO_LIBAACS"; then
        do_pacman_install -m bison flex
        sed -ri 's;bin_PROGRAMS.*;bin_PROGRAMS = ;' Makefile.am
        do_autoreconf
        do_uninstall "${_check[@]}" include/libaacs
        do_separate_confmakeinstall video --enable-shared --with-libgcrypt-prefix="$MINGW_PREFIX"
        mv -f "$LOCALDESTDIR/bin/libaacs-0.dll" "$LOCALDESTDIR/bin-video/libaacs.dll"
        rm -f "$LOCALDESTDIR/bin-video/${MINGW_CHOST}-aacs_info.exe"
        do_checkIfExist
    fi

    _check=(bin-video/libbdplus.dll libbdplus.{{,l}a,pc} libbdplus/bdplus.h)
    if do_vcs "$SOURCE_REPO_LIBBDPLUS"; then
        sed -ri 's;noinst_PROGRAMS.*;noinst_PROGRAMS = ;' Makefile.am
        do_autoreconf
        do_uninstall "${_check[@]}" include/libbdplus
        do_separate_confmakeinstall video --enable-shared
        mv -f "$LOCALDESTDIR/bin/libbdplus-0.dll" "$LOCALDESTDIR/bin-video/libbdplus.dll"
        do_checkIfExist
    fi
fi

_check=(libbluray.{{,l}a,pc})
if { { [[ $ffmpeg != no ]] && enabled libbluray; } || ! mpv_disabled libbluray; } &&
    do_vcs "$SOURCE_REPO_LIBBLURAY"; then
    [[ -f contrib/libudfread/.git ]] || do_git_submodule
    do_patch "https://raw.githubusercontent.com/m-ab-s/mabs-patches/master/libbluray/0001-dec-prefix-with-libbluray-for-now.patch" am
    do_autoreconf
    do_uninstall include/libbluray share/java "${_check[@]}"
    sed -i 's|__declspec(dllexport)||g' jni/win32/jni_md.h
    extracommands=()
    log javahome get_java_home
    OLD_PATH=$PATH
    if [[ -n $JAVA_HOME ]]; then
        if [[ ! -f /opt/apache-ant/bin/ant ]] ; then
            apache_ant_ver=$(clean_html_index "https://www.apache.org/dist/ant/binaries/")
            apache_ant_ver=$(get_last_version "$apache_ant_ver" "apache-ant" "1\.\d+\.\d+")
            if do_wget -r -c \
                "https://www.apache.org/dist/ant/binaries/apache-ant-${apache_ant_ver:-1.10.6}-bin.zip" \
                apache-ant.zip; then
                rm -rf /opt/apache-ant
                mv apache-ant /opt/apache-ant
            fi
        fi
        PATH=/opt/apache-ant/bin:$JAVA_HOME/bin:$PATH
        log ant-diagnostics ant -diagnostics
        export JDK_HOME=''
        export JAVA_HOME
    else
        extracommands+=(--disable-bdjava-jar)
    fi
    if enabled libxml2; then
        sed -ri 's;(Cflags.*);\1 -DLIBXML_STATIC;' src/libbluray.pc.in
    else
        extracommands+=(--without-libxml2)
    fi
    CFLAGS+=" $(enabled libxml2 && echo "-DLIBXML_STATIC")" \\
        do_separate_confmakeinstall --disable-{examples,doxygen-doc} \
        --without-{fontconfig,freetype} "${extracommands[@]}"
    do_checkIfExist
    PATH=$OLD_PATH
    unset extracommands JDK_HOME JAVA_HOME OLD_PATH
fi

_check=(libxavs.a xavs.{h,pc})
if [[ $ffmpeg != no ]] && enabled libxavs && do_pkgConfig "xavs = 0.1." "0.1" &&
    do_vcs "$SOURCE_REPO_XAVS"; then
    do_pacman_install yasm
    do_patch "https://github.com/Distrotech/xavs/pull/1.patch" am
    [[ -f libxavs.a ]] && log "distclean" make distclean
    do_uninstall "${_check[@]}"
    sed -i 's|"NUL"|"/dev/null"|g' configure
    do_configure
    do_make libxavs.a
    for _file in xavs.h libxavs.a xavs.pc; do do_install "$_file"; done
    do_checkIfExist
    unset _file
fi

_check=(libxavs2.a xavs2_config.h xavs2.{h,pc})
[[ $standalone = y ]] && _check+=(bin-video/xavs2.exe)
if [[ $bits = 32bit ]]; then
    do_removeOption --enable-libxavs2
elif { [[ $avs2 = y ]] || { [[ $ffmpeg != no ]] && enabled libxavs2; }; } &&
    do_vcs "$SOURCE_REPO_XAVS2"; then
    do_patch "https://github.com/pkuvcl/xavs2/compare/master...1480c1:xavs2:gcc14/pointerconversion.patch" am
    cd_safe build/linux
    [[ -f config.mak ]] && log "distclean" make distclean
    do_uninstall all "${_check[@]}"
    do_configure --bindir="$LOCALDESTDIR"/bin-video --enable-static --enable-strip
    do_makeinstall
    do_checkIfExist
fi

_check=(libdavs2.a davs2_config.h davs2.{h,pc})
[[ $standalone = y ]] && _check+=(bin-video/davs2.exe)
if [[ $bits = 32bit ]]; then
    do_removeOption --enable-libdavs2
elif { [[ $avs2 = y ]] || { [[ $ffmpeg != no ]] && enabled libdavs2; }; } &&
    do_vcs "$SOURCE_REPO_DAVS"; then
    cd_safe build/linux
    [[ -f config.mak ]] && log "distclean" make distclean
    do_uninstall all "${_check[@]}"
    do_configure --bindir="$LOCALDESTDIR"/bin-video --enable-strip
    do_makeinstall
    do_checkIfExist
fi

_check=(libuavs3d.a uavs3d.{h,pc})
[[ $standalone = y ]] && _check+=(bin-video/uavs3dec.exe)
if [[ $ffmpeg != no ]] && enabled libuavs3d &&
    do_vcs "$SOURCE_REPO_UAVS3D"; then
    do_cmakeinstall
    [[ $standalone = y ]] && do_install uavs3dec.exe bin-video/
    do_checkIfExist
fi

_check=(libdovi.a libdovi/rpu_parser.h dovi.pc bin-video/dovi_tool.exe)
if [[ $dovitool = y ]] &&
    do_vcs "$SOURCE_REPO_DOVI_TOOL"; then
    do_uninstall "${_check[@]}" include/libdovi bin-video/dovi.dll dovi.def dovi.dll.a
    do_rust
    do_install "target/$CARCH-pc-windows-gnu$rust_target_suffix/release/dovi_tool.exe" bin-video/
    cd_safe dolby_vision
    do_rustcinstall --bindir="$LOCALDESTDIR"/bin-video/ --library-type=staticlib
    do_checkIfExist
fi

_check=(bin-video/hdr10plus_tool.exe)
if [[ $hdr10plustool = y ]] &&
    do_vcs "$SOURCE_REPO_HDR10PLUS_TOOL"; then
    do_uninstall "${_check[@]}"
    do_rust
    do_install "target/$CARCH-pc-windows-gnu$rust_target_suffix/release/hdr10plus_tool.exe" bin-video/
    do_checkIfExist
fi

if [[ $mediainfo = y ]]; then
    [[ $curl = openssl ]] && hide_libressl
    _check=(libzen.{a,pc})
    if do_vcs "$SOURCE_REPO_LIBZEN" libzen; then
        do_uninstall include/ZenLib bin-global/libzen-config \
            "${_check[@]}" libzen.la lib/cmake/zenlib
        do_cmakeinstall Project/CMake
        do_checkIfExist
    fi
    fix_cmake_crap_exports "$LOCALDESTDIR/lib/cmake/zenlib"

    sed -i 's;message(FATAL_ERROR "The imported target;message(WARNING "The imported target;' \
        "$MINGW_PREFIX"/lib/cmake/CURL/CURLTargets.cmake
    _check=(libmediainfo.{a,pc})
    _deps=(lib{zen,curl}.a)
<<<<<<< HEAD
    if do_vcs "https://github.com/g-maxime/MediaInfoLib.git#mingw" libmediainfo; then
=======
    if do_vcs "$SOURCE_REPO_LIBMEDIAINFO" libmediainfo; then
>>>>>>> 961953c9 (resolve upstream conflicts)
        do_uninstall include/MediaInfo{,DLL} bin-global/libmediainfo-config \
            "${_check[@]}" libmediainfo.la lib/cmake/mediainfolib
        CFLAGS+=" $($PKG_CONFIG --cflags libzen)" \
        LDFLAGS+=" $($PKG_CONFIG --cflags --libs libzen)" \
            do_cmakeinstall Project/CMake -DBUILD_ZLIB=off -DBUILD_ZENLIB=off
        do_checkIfExist
    fi
    fix_cmake_crap_exports "$LOCALDESTDIR/lib/cmake/mediainfolib"

    _check=(bin-video/mediainfo.exe)
    _deps=(libmediainfo.a)
    if do_vcs "$SOURCE_REPO_MEDIAINFO" mediainfo; then
        cd_safe Project/GNU/CLI
        do_autogen
        do_uninstall "${_check[@]}"
        [[ -f Makefile ]] && log distclean make distclean
        do_configure --disable-shared --bindir="$LOCALDESTDIR/bin-video" \
            --enable-staticlibs
        do_makeinstall
        do_checkIfExist
    fi
    [[ $curl = openssl ]] && hide_libressl -R
fi

if [[ $ffmpeg != no ]] && enabled libvidstab; then
    do_pacman_install omp
    _check=(libvidstab.a vidstab.pc)
    if do_vcs "$SOURCE_REPO_VIDSTAB" vidstab; then
        do_uninstall include/vid.stab "${_check[@]}"
        do_cmakeinstall
        do_checkIfExist
    fi
fi

_check=(libzvbi.{h,{,l}a} zvbi-0.2.pc)
if [[ $ffmpeg != no ]] && enabled libzvbi &&
    do_vcs "$SOURCE_REPO_ZVBI"; then
    do_uninstall "${_check[@]}" zvbi-0.2.pc
    do_autoreconf
    do_separate_conf --disable-{dvb,bktr,examples,nls,proxy,tests} --without-doxygen
    cd_safe src
    do_makeinstall
    cd_safe ..
    log pkgconfig make SUBDIRS=. install
    do_checkIfExist
    unset _vlc_zvbi_patches
fi

if [[ $ffmpeg != no ]] && enabled_any frei0r ladspa; then
    _check=(libdl.a dlfcn.h)
    if do_vcs "$SOURCE_REPO_DLFCN"; then
        do_uninstall "${_check[@]}"
        do_cmakeinstall
        do_checkIfExist
    fi

    _check=(frei0r.{h,pc})
    if do_vcs "$SOURCE_REPO_FREI0R"; then
        sed -i 's/find_package (Cairo)//' "CMakeLists.txt"
        do_uninstall lib/frei0r-1 "${_check[@]}"
        do_pacman_install gavl
        do_cmakeinstall -DWITHOUT_OPENCV=on
        do_checkIfExist
    fi
fi

_check=(DeckLinkAPI.h DeckLinkAPIVersion.h DeckLinkAPI_i.c)
if [[ $ffmpeg != no ]] && enabled decklink &&
    do_vcs "$SOURCE_REPO_DECKLINK"; then
    do_makeinstall PREFIX="$LOCALDESTDIR"
    do_checkIfExist
fi

_check=(libvpl.a vpl.pc)
if [[ $ffmpeg != no ]] && enabled libvpl; then
    if enabled libmfx; then
        do_removeOption --enable-libmfx
    fi
    if do_vcs "$SOURCE_REPO_LIBVPL" libvpl; then
    if [[ $bits = 32bit ]]; then
        do_patch https://raw.githubusercontent.com/msys2/MINGW-packages/master/mingw-w64-libvpl/0003-cmake-fix-32bit-install.patch
    fi
    do_uninstall include/vpl "${_check[@]}"
    do_cmakeinstall -DUNIX=OFF
    do_checkIfExist
    fi
fi

_check=(libmfx.{{,l}a,pc})
if [[ $ffmpeg != no ]] && enabled libmfx &&
    do_vcs "$SOURCE_REPO_LIBMFX" libmfx; then
    do_autoreconf
    do_uninstall include/mfx "${_check[@]}"
    do_separate_confmakeinstall
    do_checkIfExist
fi

_check=(AMF/core/Version.h)
if [[ $ffmpeg != no ]] && { enabled amf || ! disabled_any autodetect amf; } &&
    do_vcs "$SOURCE_REPO_AMF"; then
    do_uninstall include/AMF
    cd_safe amf/public/include
    install -D -p -t "$LOCALDESTDIR/include/AMF/core" core/*.h
    install -D -p -t "$LOCALDESTDIR/include/AMF/components" components/*.h
    do_checkIfExist
fi

_check=(libgpac_static.a bin-video/{MP4Box,gpac}.exe)
if [[ $mp4box = y ]] && do_vcs "$SOURCE_REPO_GPAC"; then
    do_uninstall include/gpac "${_check[@]}"
    git grep -PIl "\xC2\xA0" | xargs -r sed -i 's/\xC2\xA0/ /g'
    # Disable passing rpath to the linker, as it's a no-op with ld, but an error with lld
    find . -name "Makefile" -exec grep -q rpath {} \; -exec sed -i '/^LINKFLAGS.*-rpath/s/^/#/' {} +
    LIBRARY_PATH="$(cygpath -pm "$LOCALDESTDIR/lib:$MINGW_PREFIX/lib")" \\
        do_separate_conf --static-bin --static-build --static-modules
    do_make
    log "install" make install-lib
    do_install bin/gcc/MP4Box.exe bin/gcc/gpac.exe bin-video/
    do_checkIfExist
fi

_check=(SvtHevcEnc.pc libSvtHevcEnc.a svt-hevc/EbApi.h
    bin-video/SvtHevcEncApp.exe)
if [[ $bits = 32bit ]]; then
    do_removeOption --enable-libsvthevc
elif { [[ $svthevc = y ]] || enabled libsvthevc; } &&
    do_vcs "$SOURCE_REPO_SVTHEVC"; then
    do_uninstall include/svt-hevc "${_check[@]}" include/svt-hevc
    do_cmakeinstall video -DUNIX=OFF
    do_checkIfExist
fi

_check=(bin-video/SvtVp9EncApp.exe
    libSvtVp9Enc.a SvtVp9Enc.pc)
if [[ $bits = 32bit ]]; then
    do_removeOption --enable-libsvtvp9
elif { [[ $svtvp9 = y ]] || enabled libsvtvp9; } &&
    do_vcs "$SOURCE_REPO_SVTVP9"; then
    do_uninstall include/svt-vp9 "${_check[@]}" include/svt-vp9
    do_cmakeinstall video -DUNIX=OFF
    do_checkIfExist
fi

_check=(xvc.pc xvc{enc,dec}.h libxvc{enc,dec}.a bin-video/xvc{enc,dec}.exe)
if [[ $xvc == y ]] &&
    do_vcs "$SOURCE_REPO_XVC"; then
    do_patch "https://github.com/divideon/xvc/compare/master...1480c1:xvc:stdint.patch" am
    do_uninstall "${_check[@]}"
    do_cmakeinstall video -DBUILD_TESTS=OFF -DENABLE_ASSERTIONS=OFF
    do_checkIfExist
fi

if [[ $x264 != no ]] ||
    { [[ $ffmpeg != no ]] && enabled libx264; }; then
    _check=(x264{,_config}.h libx264.a x264.pc)
    [[ $standalone = y || $av1an != n ]] && _check+=(bin-video/x264.exe)
    _bitdepth=$(get_api_version x264_config.h BIT_DEPTH)
    if do_vcs "$SOURCE_REPO_X264" ||
        [[ $x264 = o8   && $_bitdepth =~ (0|10) ]] ||
        [[ $x264 = high && $_bitdepth =~ (0|8) ]] ||
        [[ $x264 =~ (yes|full|shared|fullv) && "$_bitdepth" != 0 ]]; then

        extracommands=("--host=$MINGW_CHOST" "--prefix=$LOCALDESTDIR"
            "--bindir=$LOCALDESTDIR/bin-video")

        # light ffmpeg build
        old_PKG_CONFIG_PATH=$PKG_CONFIG_PATH
        PKG_CONFIG_PATH=$LOCALDESTDIR/opt/lightffmpeg/lib/pkgconfig:$MINGW_PREFIX/lib/pkgconfig
        unset_extra_script
        if [[ $standalone = y || $av1an != n ]] && [[ $x264 =~ (full|fullv) ]]; then
            _check=("$LOCALDESTDIR"/opt/lightffmpeg/lib/pkgconfig/libav{codec,format}.pc)
            do_vcs "$ffmpegPath"
            do_uninstall "$LOCALDESTDIR"/opt/lightffmpeg
            [[ -f config.mak ]] && log "distclean" make distclean
            create_build_dir light
            if [[ $x264 = fullv ]]; then
                mapfile -t audio_codecs < <(
                    sed -n '/audio codecs/,/external libraries/p' ../libavcodec/allcodecs.c |
                    sed -n 's/^[^#]*extern.* *ff_\\([^ ]*\\)_decoder;/\\1/p')
                config_path=.. LDFLAGS+=" -L$MINGW_PREFIX/lib" \\
                    do_configure "${FFMPEG_BASE_OPTS[@]}" \\
                    --prefix="$LOCALDESTDIR/opt/lightffmpeg" \\
                    --disable-{programs,devices,filters,encoders,muxers,debug,sdl2,network,protocols,doc} \\
                    --enable-protocol=file,pipe \\
                    --disable-decoder="$(IFS=, ; echo "${audio_codecs[*]}")" --enable-gpl \\
                    --disable-bsf=aac_adtstoasc,text2movsub,noise,dca_core,mov2textsub,mp3_header_decompress \\
                    --disable-autodetect --enable-{lzma,bzlib,zlib}
                unset audio_codecs
            else
                config_path=.. LDFLAGS+=" -L$MINGW_PREFIX/lib" \\
                    do_configure "${FFMPEG_BASE_OPTS[@]}" \\
                    --prefix="$LOCALDESTDIR/opt/lightffmpeg" \\
                    --disable-{programs,devices,filters,encoders,muxers,debug,sdl2,doc} --enable-gpl
            fi
            do_makeinstall
            files_exist "${_check[@]}" && touch "build_successful${bits}_light"
            unset_extra_script

            _check=("$LOCALDESTDIR"/opt/lightffmpeg/lib/pkgconfig/ffms2.pc bin-video/ffmsindex.exe)
            if do_vcs "$SOURCE_REPO_FFMS2"; then
                do_uninstall "${_check[@]}"
                sed -i 's/Cflags.*/& -DFFMS_STATIC/' ffms2.pc.in
                do_patch "https://raw.githubusercontent.com/m-ab-s/mabs-patches/master/ffms2/0001-ffmsindex-fix-linking-issues.patch" am
                mkdir -p src/config
                do_autoreconf
                do_separate_confmakeinstall video --prefix="$LOCALDESTDIR/opt/lightffmpeg"
                do_checkIfExist
            fi
            cd_safe "$LOCALBUILDDIR"/x264-git
        else
            extracommands+=(--disable-lavf --disable-ffms)
        fi

        if [[ $standalone = y || $av1an != n ]]; then
            _check=("$LOCALDESTDIR/opt/lightffmpeg/lib/pkgconfig/liblsmash.pc")
            if do_vcs "$SOURCE_REPO_LIBLSMASH" liblsmash; then
                [[ -f config.mak ]] && log "distclean" make distclean
                do_uninstall "${_check[@]}"
                create_build_dir
                log configure ../configure --prefix="$LOCALDESTDIR/opt/lightffmpeg"
                do_make install-lib
                do_checkIfExist
            fi
            cd_safe "$LOCALBUILDDIR"/x264-git
        else
            extracommands+=(--disable-cli)
        fi

        _check=(x264{,_config}.h x264.pc)
        [[ $standalone = y || $av1an != n ]] && _check+=(bin-video/x264.exe)
        [[ -f config.h ]] && log "distclean" make distclean

        x264_build=$(grep ' X264_BUILD ' x264.h | cut -d' ' -f3)
        if [[ $x264 = shared ]]; then
            extracommands+=(--enable-shared)
            _check+=(libx264.dll.a bin-video/libx264-"${x264_build}".dll)
        else
            extracommands+=(--enable-static)
            _check+=(libx264.a)
        fi

        case $x264 in
        high) extracommands+=("--bit-depth=10") ;;
        o8) extracommands+=("--bit-depth=8") ;;
        *) extracommands+=("--bit-depth=all") ;;
        esac

        do_uninstall "${_check[@]}"
        check_custom_patches
        create_build_dir
        extra_script pre configure
        PKGCONFIG="$PKG_CONFIG" CFLAGS="${CFLAGS// -O2 / }" \\
            log configure ../configure "${extracommands[@]}"
        extra_script post configure
        do_make
        do_makeinstall
        do_checkIfExist
        PKG_CONFIG_PATH=$old_PKG_CONFIG_PATH
        unset extracommands x264_build old_PKG_CONFIG_PATH
    fi
    unset _bitdepth
else
    pc_exists x264 || do_removeOption --enable-libx264
fi

_check=(x265{,_config}.h libx265.a x265.pc)
[[ $standalone = y || $av1an != n ]] && _check+=(bin-video/x265.exe)
if [[ ! $x265 = n ]] && do_vcs "$SOURCE_REPO_X265"; then
    grep_and_sed CMAKE_CXX_IMPLICIT_LINK_LIBRARIES source/CMakeLists.txt 's|\$\{CMAKE_CXX_IMPLICIT_LINK_LIBRARIES\}||g'
    grep_or_sed cstdint source/dynamicHDR10/json11/json11.cpp "/cstdlib/ i\#include <cstdint>"
    do_uninstall libx265{_main10,_main12}.a bin-video/libx265_main{10,12}.dll "${_check[@]}"
    [[ $bits = 32bit ]] && assembly=-DENABLE_ASSEMBLY=OFF
    [[ $x265 = d ]] && xpsupport=-DWINXP_SUPPORT=ON

    build_x265() {
        create_build_dir
        local build_root=$PWD
        mkdir -p {8,10,12}bit

    do_x265_cmake() {
        do_print_progress "Building $1" && shift 1
        extra_script pre cmake
        log "cmake" cmake "$(get_first_subdir -f)/source" -G Ninja \
        -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
        -DCMAKE_INSTALL_PREFIX="$LOCALDESTDIR" -DBIN_INSTALL_DIR="$LOCALDESTDIR/bin-video" \
        -DENABLE_SHARED=OFF -DENABLE_CLI=OFF -DHIGH_BIT_DEPTH=ON \
        -DENABLE_HDR10_PLUS=ON $xpsupport -DCMAKE_CXX_COMPILER="$LOCALDESTDIR/bin/${CXX#ccache }.bat" \
        -DCMAKE_TOOLCHAIN_FILE="$LOCALDESTDIR/etc/toolchain.cmake" "$@"
        extra_script post cmake
        do_ninja
    }
    [[ $standalone = y || $av1an != n ]] && cli=-DENABLE_CLI=ON

    if [[ $x265 =~ (o12|s|d|y) ]]; then
        cd_safe "$build_root/12bit"
        if [[ $x265 = s ]]; then
            do_x265_cmake "shared 12-bit lib" $assembly -DENABLE_SHARED=ON -DMAIN12=ON
            do_install libx265.dll bin-video/libx265_main12.dll
            _check+=(bin-video/libx265_main12.dll)
        elif [[ $x265 = o12 ]]; then
            do_x265_cmake "12-bit lib/bin" $assembly $cli -DMAIN12=ON
        else
            do_x265_cmake "12-bit lib for multilib" $assembly -DEXPORT_C_API=OFF -DMAIN12=ON
            cp libx265.a ../8bit/libx265_main12.a
        fi
    fi

    if [[ $x265 =~ (o10|s|d|y) ]]; then
        cd_safe "$build_root/10bit"
        if [[ $x265 = s ]]; then
            do_x265_cmake "shared 10-bit lib" $assembly -DENABLE_SHARED=ON
            do_install libx265.dll bin-video/libx265_main10.dll
            _check+=(bin-video/libx265_main10.dll)
        elif [[ $x265 = o10 ]]; then
            do_x265_cmake "10-bit lib/bin" $assembly $cli
        else
            do_x265_cmake "10-bit lib for multilib" $assembly -DEXPORT_C_API=OFF
            cp libx265.a ../8bit/libx265_main10.a
        fi
    fi

    if [[ $x265 =~ (o8|s|d|y) ]]; then
        cd_safe "$build_root/8bit"
        if [[ $x265 = s || $x265 = o8 ]]; then
            do_x265_cmake "8-bit lib/bin" $cli -DHIGH_BIT_DEPTH=OFF
        else
            do_x265_cmake "multilib lib/bin" -DEXTRA_LIB="x265_main10.a;x265_main12.a" \
                -DEXTRA_LINK_FLAGS=-L. $cli -DHIGH_BIT_DEPTH=OFF -DLINKED_{10,12}BIT=ON
            mv libx265.a libx265_main.a
            ar -M <<EOF
CREATE libx265.a
ADDLIB libx265_main.a
ADDLIB libx265_main10.a
ADDLIB libx265_main12.a
SAVE
END
EOF
        fi
    }
    build_x265
    cpuCount=1 log "install" ninja install
    if [[ $standalone = y || $av1an != n ]] && [[ $x265 = d ]]; then
        cd_safe "$(get_first_subdir -f)"
        do_uninstall bin-video/x265-numa.exe
        do_print_progress "Building NUMA version of binary"
        xpsupport="" build_x265
        do_install x265.exe bin-video/x265-numa.exe
        _check+=(bin-video/x265-numa.exe)
    fi
    do_checkIfExist
    unset xpsupport assembly cli
else
    pc_exists x265 || do_removeOption "--enable-libx265"
fi
pc_exists x265 && sed -i 's|-lmingwex||g' "$(file_installed x265.pc)"

_check=(xvid.h libxvidcore.a bin-video/xvid_encraw.exe)
if enabled libxvid && [[ $standalone = y ]] &&
    do_vcs "$SOURCE_REPO_XVID"; then
    do_pacman_install yasm
    do_patch "https://github.com/m-ab-s/xvid/compare/lighde.patch" am
    do_patch "https://github.com/m-ab-s/xvid/compare/mabs.patch" am
    do_pacman_remove xvidcore
    do_uninstall "${_check[@]}"
    cd_safe xvidcore/build/generic
    log "bootstrap" ./bootstrap.sh
    do_configure
    do_make
    do_install ../../src/xvid.h include/
    do_install '=build/libxvidcore.a' libxvidcore.a
    do_install '=build/libxvidcore.dll' bin-video/
    cd_safe ../../examples
    do_make xvid_encraw
    do_install xvid_encraw.exe bin-video/
    do_checkIfExist
fi

_check=(ffnvcodec/nvEncodeAPI.h ffnvcodec.pc)
if [[ $ffmpeg != no ]] && { enabled ffnvcodec ||
    ! disabled_any ffnvcodec autodetect || ! mpv_disabled cuda-hwaccel; } &&
    do_vcs "$SOURCE_REPO_FFNVCODEC" ffnvcodec; then
    do_makeinstall PREFIX="$LOCALDESTDIR"
    do_checkIfExist
fi

if enabled libsrt; then
    do_pacman_install openssl
    _check=(libsrt.a srt.pc srt/srt.h)
    [[ $standalone = y ]] && _check+=(bin-video/srt-live-transmit.exe)
    if do_vcs "$SOURCE_REPO_SRT"; then
        hide_libressl
        do_cmakeinstall video -DENABLE_SHARED=off -DENABLE_SUFLIP=off \
            -DENABLE_EXAMPLES=off -DUSE_OPENSSL_PC=on -DUSE_STATIC_LIBSTDCXX=ON
        hide_libressl -R
        do_checkIfExist
    fi
fi

if enabled librist; then
    do_pacman_install cjson
    _check=(librist.{a,pc} librist/librist.h)
    [[ $standalone = y ]] && _check+=(bin-global/rist{sender,receiver,2rist,srppasswd}.exe)
    if do_vcs "$SOURCE_REPO_LIBRIST"; then
        do_uninstall include/librist "${_check[@]}"
        extracommands=("-Dbuiltin_cjson=false")
        [[ $standalone = y ]] || extracommands+=("-Dbuilt_tools=false")
        do_mesoninstall global -Dhave_mingw_pthreads=true -Dtest=false "${extracommands[@]}"
        do_checkIfExist
        unset extracommands
    fi
fi

_vapoursynth_install() {
    if [[ $bits = 32bit ]]; then
        do_simple_print "${orange}Vapoursynth is known to be broken on 32-bit and will be disabled"'!'"${reset}"
        return 1
    fi
    do_pacman_install tools-git
    _python_ver=3.12.10
    _python_lib=python312
    _vsver=72
    _check=("lib$_python_lib.a")
    if files_exist "${_check[@]}"; then
        do_print_status "python $_python_ver" "$green" "Up-to-date"
    elif do_wget "https://www.python.org/ftp/python/$_python_ver/python-$_python_ver-embed-amd64.zip"; then
        gendef "$_python_lib.dll" >/dev/null 2>&1
        do_dlltool "lib$_python_lib.a" "$_python_lib.def"
        [[ -f lib$_python_lib.a ]] && do_install "lib$_python_lib.a"
        do_checkIfExist
    fi

    _check=(lib{vapoursynth,vsscript}.a vapoursynth{,-script}.pc vapoursynth/{VS{Helper,Script},VapourSynth}.h)
    if pc_exists "vapoursynth = $_vsver" && files_exist "${_check[@]}"; then
        do_print_status "vapoursynth R$_vsver" "$green" "Up-to-date"
    elif do_wget "https://github.com/vapoursynth/vapoursynth/releases/download/R$_vsver/VapourSynth${bits%bit}-Portable-R$_vsver.zip"; then
        do_uninstall "bin-video/vapoursynth" "${_check[@]}"
        do_install sdk/include/vapoursynth/*.h include/vapoursynth/

        # Extract the .dll from the pip wheel
        log "7z" 7z e -y -aoa wheel/vapoursynth-$_vsver-cp${_python_lib:6:3}-abi3-win_amd64.whl \
            vapoursynth-$_vsver.data/data/Lib/site-packages/vapoursynth.dll

        create_build_dir
        declare -A _pc_vars=(
            [vapoursynth-name]=vapoursynth
            [vapoursynth-description]='A frameserver for the 21st century'
            [vapoursynth-cflags]="-DVS_CORE_EXPORTS"

            [vsscript-name]=vapoursynth-script
            [vsscript-description]='Library for interfacing VapourSynth with Python'
            [vsscript-private]="-l$_python_lib"
        )
        for _file in vapoursynth vsscript; do
            gendef - "../$_file.dll" 2>/dev/null |
                sed -E 's|^_||;s|@[1-9]+$||' > "${_file}.def"
            do_dlltool "lib${_file}.a" "${_file}.def"
            [[ -f lib${_file}.a ]] && do_install "lib${_file}.a"
            # shellcheck disable=SC2016
            printf '%s\n' \
               "prefix=$LOCALDESTDIR" \
               'exec_prefix=${prefix}' \
               'libdir=${exec_prefix}/lib' \
               'includedir=${prefix}/include/vapoursynth' \
               "Name: ${_pc_vars[${_file}-name]}" \
               "Description: ${_pc_vars[${_file}-description]}" \
               "Version: $_vsver" \
               "Libs: -L\${libdir} -l${_file}" \
               "Libs.private: ${_pc_vars[${_file}-private]}" \
               "Cflags: -I\${includedir} ${_pc_vars[${_file}-cflags]}" \
               > "${_pc_vars[${_file}-name]}.pc"
        done

        do_install vapoursynth{,-script}.pc lib/pkgconfig/
        do_checkIfExist
    fi
    unset _file _python_lib _python_ver _vsver _pc_vars
    return 0
}
if ! { { ! mpv_disabled vapoursynth || enabled vapoursynth || [[ $av1an != n ]]; } && _vapoursynth_install; }; then
    mpv_disable vapoursynth
    do_removeOption --enable-vapoursynth
fi

if [[ $av1an != n ]]; then
    local av1an_bindir="bin-video"
    local av1an_ffmpeg_prefix="opt/av1anffmpeg"
    [[ $av1an = shared ]] && av1an_bindir="bin-video/av1an/bin" && av1an_ffmpeg_prefix="bin-video/av1an"

    _check=("$LOCALDESTDIR"/"$av1an_ffmpeg_prefix"/lib/pkgconfig/lib{av{codec,device,filter,format,util},swscale}.pc)
    if flavor=av1an do_vcs "https://git.ffmpeg.org/ffmpeg.git#branch=release/7.1"; then
        do_uninstall "$LOCALDESTDIR"/"$av1an_ffmpeg_prefix"
        [[ -f config.mak ]] && log "distclean" make distclean
        local av1an_ffmpeg_opts=("--enable-static" "--disable-shared")
        [[ $av1an = shared ]] && av1an_ffmpeg_opts=("--disable-static" "--enable-shared")
        # compile ffmpeg executable if ffmpeg is disabled so av1an can function
        if [[ $ffmpeg != no ]]; then
            av1an_ffmpeg_opts+=("--disable-programs")
        else
            # enable filters too so they can be used with av1an
            av1an_ffmpeg_opts+=("--disable-ffprobe" "--disable-ffplay" "--enable-filters")
        fi
        create_build_dir av1an
        config_path=.. do_configure "${FFMPEG_BASE_OPTS[@]}" \
            --prefix="$LOCALDESTDIR/$av1an_ffmpeg_prefix" \
            --disable-autodetect --disable-everything \
            --disable-{debug,doc,network} \
            --enable-{decoders,demuxers,protocols} \
            "${av1an_ffmpeg_opts[@]}"
        do_make && do_makeinstall
        # move static ffmpeg to a reasonable location if ffmpeg is disabled
        [[ $av1an != shared ]] && [[ $ffmpeg = no ]] && [[ ! -f "$LOCALDESTDIR"/bin-video/ffmpeg.exe ]] &&
            mv -f "$LOCALDESTDIR"/{"$av1an_ffmpeg_prefix"/bin,bin-video}/ffmpeg.exe
        files_exist "${_check[@]}" && touch ../"build_successful${bits}_av1an"
        unset av1an_ffmpeg_opts
    fi

    old_PKG_CONFIG_PATH=$PKG_CONFIG_PATH
    PKG_CONFIG_PATH=$LOCALDESTDIR/$av1an_ffmpeg_prefix/lib/pkgconfig:$PKG_CONFIG_PATH

    _check=("$av1an_bindir"/av1an.exe)
    if do_vcs "$SOURCE_REPO_AV1AN"; then
        do_uninstall "${_check[@]}"
        do_pacman_install clang
        PKG_CONFIG="$LOCALDESTDIR/bin/ab-pkg-config-static.bat" \\
            LIBCLANG_PATH="$MINGW_PREFIX/bin" VAPOURSYNTH_LIB_DIR="$LOCALDESTDIR/lib" do_rust
        do_install "target/$CARCH-pc-windows-gnu$rust_target_suffix/release/av1an.exe" $av1an_bindir/
        do_checkIfExist
    fi

    PKG_CONFIG_PATH=$old_PKG_CONFIG_PATH
    unset old_PKG_CONFIG_PATH av1an_{bindir,ffmpeg_prefix}
fi

if [[ $ffmpeg != no ]] && enabled liblensfun; then
    do_pacman_install glib2
    grep_or_sed liconv "$MINGW_PREFIX"/lib/pkgconfig/glib-2.0.pc" 's;-lintl;& -liconv;'
    _check=(liblensfun.a lensfun.pc lensfun/lensfun.h)
    if do_vcs "$SOURCE_REPO_LENSFUN"; then
        do_patch "https://github.com/m-ab-s/mabs-patches/raw/master/lensfun/0001-CMake-exclude-mingw-w64-from-some-msvc-exclusive-thi.patch" am
        do_patch "https://github.com/m-ab-s/mabs-patches/raw/master/lensfun/0002-CMake-don-t-add-glib2-s-includes-as-SYSTEM-dirs.patch" am
        do_uninstall "bin-video/lensfun" "${_check[@]}"
        CFLAGS+=" -DGLIB_STATIC_COMPILATION" CXXFLAGS+=" -DGLIB_STATIC_COMPILATION" \
            do_cmakeinstall -DBUILD_STATIC=on -DBUILD_{TESTS,LENSTOOL,DOC}=off \
            -DINSTALL_HELPER_SCRIPTS=off -DCMAKE_INSTALL_DATAROOTDIR="$LOCALDESTDIR/bin-video" \
            -DINSTALL_PYTHON_MODULE=OFF
        do_checkIfExist
    fi
fi

_check=(libshout.{,l}a shout.pc shout/shout.h)
if do_vcs "https://gitlab.xiph.org/xiph/icecast-libshout.git" libshout; then
    do_git_submodule
    do_uninstall "${_check[@]}"
    do_autoreconf
    CFLAGS+=" -include ws2tcpip.h" do_separate_confmakeinstall --disable-examples LIBS="$($PKG_CONFIG --libs openssl)"
    do_checkIfExist
fi

_check=(bin/protoc.exe libprotobuf-lite.{,l}a libprotobuf.{,l}a protobuf{,-lite}.pc)
if do_vcs "https://github.com/protocolbuffers/protobuf.git"; then
    do_uninstall include/google/protobuf "${_check[@]}"
    do_autogen
    do_separate_confmakeinstall
    do_checkIfExist
fi

_check=(pixman-1.pc libpixman-1.a pixman-1/pixman.h)
if do_vcs "https://gitlab.freedesktop.org/pixman/pixman.git"; then
    do_uninstall include/pixman-1 "${_check[@]}"
    do_patch "https://raw.githubusercontent.com/m-ab-s/mabs-patches/master/pixman/0001-pixman-pixman-mmx-fix-redefinition-of-_mm_mulhi_pu16.patch" am
    NOCONFIGURE=y do_autogen
    CFLAGS="-msse2 -mfpmath=sse -mstackrealign $CFLAGS" \\
        do_separate_confmakeinstall
    do_checkIfExist
fi

_check=(libmedialibrary.a medialibrary.pc medialibrary/IAlbum.h)
if do_vcs "https://code.videolan.org/videolan/medialibrary.git"; then
    do_uninstall include/medialibrary "${_check[@]}"
    do_mesoninstall -Dtests=disabled -Dlibvlc=disabled
    do_checkIfExist
fi

_check=(libthai.pc libthai.{,l}a thai/thailib.h)
if do_vcs "https://github.com/tlwg/libthai.git"; then
    do_uninstall include/thai "${_check[@]}"
    do_autogen
    do_separate_confmakeinstall
    do_checkIfExist
fi

_check=(libebml.a ebml/ebml_export.h libebml.pc lib/cmake/EBML/EBMLTargets.cmake)
if do_vcs "https://github.com/Matroska-Org/libebml.git"; then
    do_uninstall include/ebml lib/cmake/EBML "${_check[@]}"
    do_cmakeinstall
    do_checkIfExist
fi

_check=(libmatroska.a libmatroska.pc matroska/KaxTypes.h lib/cmake/Matroska/MatroskaTargets.cmake)
if do_vcs "https://github.com/Matroska-Org/libmatroska.git"; then
    do_uninstall include/matroska lib/cmake/Matroska "${_check[@]}"
    do_cmakeinstall
    do_checkIfExist
fi

_check=("$LOCALDESTDIR"/vlc/bin/{{c,r}vlc,vlc.exe,libvlc.dll}
            "$LOCALDESTDIR"/vlc/libexec/vlc/vlc-cache-gen.exe
            "$LOCALDESTDIR"/vlc/lib/pkgconfig/libvlc.pc
            "$LOCALDESTDIR"/vlc/include/vlc/libvlc_version.h)
    if do_vcs "https://code.videolan.org/videolan/vlc.git"; then
        do_uninstall bin/plugins lib/vlc "${_check[@]}"
        _mabs_vlc=https://raw.githubusercontent.com/m-ab-s/mabs-patches/master/vlc
        do_patch "https://code.videolan.org/videolan/vlc/-/merge_requests/155.patch" am
        do_patch "$_mabs_vlc/0001-modules-access-srt-Use-srt_create_socket-instead-of-.patch" am
        do_patch "$_mabs_vlc/0002-modules-codec-libass-Use-ass_set_pixel_aspect-instea.patch" am
        do_patch "$_mabs_vlc/0003-Use-libdir-for-plugins-on-msys2.patch" am
        do_patch "$_mabs_vlc/0004-include-vlc_fixups.h-fix-iovec-is-redefined-errors.patch" am
        do_patch "$_mabs_vlc/0005-include-vlc_common.h-fix-snprintf-and-vsnprintf-rede.patch" am
        do_patch "$_mabs_vlc/0006-configure.ac-check-if-_WIN32_IE-is-already-defined.patch" am
        do_patch "$_mabs_vlc/0007-modules-stream_out-rtp-don-t-redefine-E-defines.patch" am
        do_patch "$_mabs_vlc/0008-include-vlc_codecs.h-don-t-redefine-WAVE_FORMAT_PCM.patch" am
        do_patch "$_mabs_vlc/0009-modules-audio_filter-channel_mixer-spatialaudio-add-.patch" am
        do_patch "$_mabs_vlc/0010-modules-access_output-don-t-put-lgpg-error-for-liveh.patch" am

        do_autoreconf
        # All of the disabled are because of multiple issues both on the installed libs and on vlc's side.
        # Maybe set up vlc_options.txt

        # Can't disable shared since vlc will error out. I don't think enabling static will really do anything for us other than breaking builds.
        create_build_dir
        config_path=".." do_configure \
            --prefix="$LOCALDESTDIR/vlc" \
            --sysconfdir="$LOCALDESTDIR/vlc/etc" \
            --{build,host,target}="$MINGW_CHOST" \
            --enable-{shared,avcodec,merge-ffmpeg,qt,nls} \
            --disable-{static,dbus,fluidsynth,svgdec,aom,mod,ncurses,mpg123,notify,svg,secret,telx,ssp,lua,gst-decode,nvdec} \
            --with-binary-version="MABS" BUILDCC="$CC" \
            CFLAGS="$CFLAGS -DGLIB_STATIC_COMPILATION -DQT_STATIC -DGNUTLS_INTERNAL_BUILD -DLIBXML_STATIC -DLIBXML_CATALOG_ENABLED" \
            LIBS="$($PKG_CONFIG --libs libcddb regex iconv) -lwsock32 -lws2_32 -lpthread -liphlpapi"
        do_makeinstall
        do_checkIfExist
        PATH="$LOCALDESTDIR/vlc/bin:$PATH" "$LOCALDESTDIR/vlc/libexec/vlc/vlc-cache-gen" "$LOCALDESTDIR/vlc/lib/plugins"
    fi
fi

if [[ $ffmbc = y ]] && do_vcs "$SOURCE_REPO_FFMBC"; then
    _notrequired=true
    create_build_dir
    # Too many errors with GCC 15 due to really old code.
    CFLAGS+=" -Wno-error=incompatible-pointer-types" \
        log configure ../configure --target-os=mingw32 --enable-gpl \
        --disable-{dxva2,ffprobe} --extra-cflags=-DNO_DSHOW_STRSAFE \
        --cc="$CC" --ld="$CXX"
    do_make
    do_install ffmbc.exe bin-video/
    do_checkIfExist
    unset _notrequired
fi

do_simple_print -p "${orange}Finished $bits compilation of all tools${reset}"
}

run_builds() {
    new_updates=no
    new_updates_packages=""
    if [[ $build32 = yes ]]; then
        source /local32/etc/profile2.local
        buildProcess
    fi

    if [[ $build64 = yes ]]; then
        source /local64/etc/profile2.local
        buildProcess
    fi
}

cd_safe "$LOCALBUILDDIR"
run_builds

if [[ $exitearly = EE2 || $exitearly = EE3 || $exitearly = EE4 || $exitearly = EE5 || $exitearly = EE6 ]]; then
    exit 0
fi

while [[ $new_updates = yes ]]; do
    ret=no
    printf '%s\n' \
        "-------------------------------------------------------------------------------" \
        "There were new updates while compiling." \
        "Updated:$new_updates_packages" \
        "Would you like to run compilation again to get those updates? Default: no"
    do_prompt "y/[n] "
    echo "-------------------------------------------------------------------------------"
    if [[ $ret = y || $ret = Y || $ret = yes ]]; then
        run_builds
    else
        break
    fi
done

clean_suite
if [[ -f $LOCALBUILDDIR/post_suite.sh ]]; then
    do_simple_print -p "${green}Executing post_suite.sh${reset}"
    source "$LOCALBUILDDIR"/post_suite.sh || true
fi
do_simple_print -p "${green}Compilation successful.${reset}"
do_simple_print -p "${green}This window will close automatically in 5 seconds.${reset}"
sleep 5
