#!/bin/sh

# Setup build env
sudo apt-get install ccache gzip cpio flex bc

# Clone toolchain from its repository
mkdir clang && curl -Lsq https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/android11-release/clang-r383902.tar.gz -o - | tar -xzf - -C clang
git clone --depth=1 https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9 -b android11-release binutils
git clone --depth=1 https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9 -b android11-release binutils-32

# Clone AnyKernel3
git clone --depth=1 https://github.com/100Daisy/AnyKernel3

# Export the PATH variable
export PATH="$(pwd)/clang/bin:$(pwd)/binutils/bin:$(pwd)/binutils-32/bin:$PATH"

# Compile the kernel
build_kernel() {
    make -j$(nproc --all) \
    O=out \
    ARCH=arm64 \
    CC=clang \
    HOSTCC=clang \
    CLANG_TRIPLE=aarch64-linux-gnu- \
    CROSS_COMPILE=aarch64-linux-android- \
    CROSS_COMPILE_ARM32=arm-linux-androideabi-
}

build_modules() {
    make -j$(nproc --all) \
    O=out \
    ARCH=arm64 \
    CC=clang \
    HOSTCC=clang \
    CLANG_TRIPLE=aarch64-linux-gnu- \
    CROSS_COMPILE=aarch64-linux-android- \
    CROSS_COMPILE_ARM32=arm-linux-androideabi- \
    M=$1
}

merge_config() {
    ARCH=arm64 \
    CC=clang \
    HOSTCC=clang \
    CLANG_TRIPLE=aarch64-linux-gnu- \
    CROSS_COMPILE=aarch64-linux-android- \
    CROSS_COMPILE_ARM32=arm-linux-androideabi- \
    scripts/kconfig/merge_config.sh -m -O arch/arm64/configs \
    $1
}

# Defconfig
merge_config 'arch/arm64/configs/vendor/bengal-perf_defconfig arch/arm64/configs/vendor/ext_config/moto-bengal.config arch/arm64/configs/vendor/ext_config/cebu-default.config'
mv arch/arm64/configs/.config arch/arm64/configs/sunburn_defconfig
make sunburn_defconfig ARCH=arm64 O=out CC=clang

build_kernel

# Zip up the kernel
zip_kernelimage() {
    cp out/arch/arm64/boot/Image.gz-dtb AnyKernel3
    BUILD_TIME=$(date +"%d%m%Y-%H%M")
    cd AnyKernel3
    KERNEL_NAME=LineageOS-$1-"${BUILD_TIME}"
    zip -r9 "$KERNEL_NAME".zip ./*
    cd ..
}

FILE="$(pwd)/out/arch/arm64/boot/Image.gz-dtb"
if [ -f "$FILE" ]; then
    zip_kernelimage $1
    KERN_FINAL="$(pwd)/AnyKernel3/"$KERNEL_NAME".zip"
    echo "The kernel has successfully been compiled and can be found in $KERN_FINAL"
else
    echo "The kernel has failed to compile. Please check the terminal output for further details."
    exit 1
fi