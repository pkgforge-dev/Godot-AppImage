#!/bin/sh

set -eu

echo "Installing build dependencies..."
echo "---------------------------------------------------------------"
pacman -Syu --noconfirm \
	brotli            \
	graphite          \
	libdecor          \
	libglvnd          \
	libogg            \
	libpng            \
	libspeechd        \
	libtheora         \
	libvorbis         \
	libwebp           \
	libwslay          \
	libxcursor        \
	libxi             \
	libxinerama       \
	openxr            \
	scons             \
	wayland-protocols \
	yasm              \
	zlib              \
	zstd

echo "Installing debloated packages..."
echo "---------------------------------------------------------------"
get-debloated-pkgs --add-common --prefer-nano

echo "Building Godot..."
echo "---------------------------------------------------------------"
git clone --filter=blob:none --no-checkout https://github.com/godotengine/godot ./godot && (
	cd ./godot

	# Build the latest stable release
	TAG=$(git tag --list '*-stable' --sort=-v:refname | head -n 1)
	git checkout "$TAG"
	VERSION="${TAG%-stable}"
	echo "$VERSION" > ~/version

	# Allow the engine to run on CPUs without SSE4.2 and POPCNT
	patch -p1 < ../patches/0001-do-not-require-sse4.2-and-popcnt.patch

	scons \
		-j"$(nproc)"              \
		platform=linuxbsd         \
		target=editor             \
		production=yes            \
		use_llvm=no               \
		werror=no                 \
		builtin_certs=yes         \
		builtin_brotli=no         \
		builtin_embree=yes        \
		builtin_freetype=no       \
		builtin_graphite=no       \
		builtin_harfbuzz=yes      \
		builtin_icu4c=yes         \
		builtin_libogg=no         \
		builtin_libpng=no         \
		builtin_libtheora=no      \
		builtin_libvorbis=no      \
		builtin_libwebp=no        \
		builtin_mbedtls=yes       \
		builtin_miniupnpc=yes     \
		builtin_openxr=no         \
		builtin_pcre2=no          \
		builtin_pcre2_with_jit=no \
		builtin_zlib=no           \
		builtin_zstd=no
)

mkdir -p ./AppDir
cp -v ./godot/bin/godot.linuxbsd.editor.*    /usr/bin/godot
cp -v ./godot/misc/logo/icon.png             ./AppDir/godot.png
cp -v ./godot/misc/dist/linux/*Godot.desktop ./AppDir/Godot.desktop

rm -rf ./godot
