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
	ninja             \
	openxr            \
	scons             \
	wayland-protocols \
	yasm              \
	zlib              \
	zstd

echo "Installing debloated packages..."
echo "---------------------------------------------------------------"
get-debloated-pkgs --add-common --prefer-nano

echo "Building polyfill-glibc..."
echo "---------------------------------------------------------------"
git clone --depth 1 https://github.com/pkgforge-dev/polyfill-glibc ./polyfill-glibc
ninja -C ./polyfill-glibc polyfill-glibc

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

	# Make the editor use the export templates bundled in the AppImage
	patch -p1 < ../patches/0002-use-bundled-export-templates.patch

	set -- \
		-j"$(nproc)"              \
		platform=linuxbsd         \
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

	scons target=editor "$@"
	scons target=template_release "$@"
	scons target=template_debug "$@"
)

read -r _ver < ~/version

# Export templates are standalone binaries, they are not made portable by
# bundling glibc in the AppImage like the editor is, so polyfill them to run
# against an older glibc (Ubuntu 22.04's 2.35)
templates=/usr/share/godot/export_templates/"${_ver}".stable
mkdir -p "$templates"

cp -v ./godot/bin/godot.linuxbsd.template_release.* "$templates"/linux_release.x86_64
cp -v ./godot/bin/godot.linuxbsd.template_debug.*   "$templates"/linux_debug.x86_64

echo "Making export templates compatible with older glibc..."
echo "---------------------------------------------------------------"
./polyfill-glibc/polyfill-glibc \
	--target-glibc=2.35                \
	"$templates"/linux_release.x86_64  \
	"$templates"/linux_debug.x86_64

# The templates are ELF binaries but Godot only reads/copies them, so drop the
# executable bit to prevent quick-sharun from deploying them as binaries
chmod 644 "$templates"/linux_release.x86_64 "$templates"/linux_debug.x86_64

mkdir -p ./AppDir
cp -v ./godot/bin/godot.linuxbsd.editor.*    /usr/bin/godot
cp -v ./godot/misc/logo/icon.png             ./AppDir/godot.png
cp -v ./godot/misc/dist/linux/*Godot.desktop ./AppDir/Godot.desktop

rm -rf ./godot
