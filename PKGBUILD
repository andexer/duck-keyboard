pkgname=duck-keyboard
pkgver=0.1.0
pkgrel=2
pkgdesc="A prank keyboard app that plays random duck sounds on every keystroke"
arch=('x86_64')
url="https://github.com/andexer/duck-keyboard"
license=('MIT')
depends=('alsa-lib' 'gcc-libs' 'glibc' 'libx11' 'libxi' 'libxtst')
makedepends=('cargo')
install="$pkgname.install"
source=()
sha256sums=()

_repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

prepare() {
  local buildsrc="$srcdir/$pkgname-$pkgver"

  rm -rf "$buildsrc"
  mkdir -p "$buildsrc"
  cp -a "$_repo_root"/. "$buildsrc"/

  rm -rf \
    "$buildsrc/.git" \
    "$buildsrc/pkg" \
    "$buildsrc/srcpkg" \
    "$buildsrc/target"
}

build() {
  cd "$srcdir/$pkgname-$pkgver"
  cargo build --release --locked
}

package() {
  cd "$srcdir/$pkgname-$pkgver"

  install -Dm755 "target/release/duck-keyboard" "$pkgdir/usr/bin/duck-keyboard"
  install -Dm755 "packaging/system-setup.sh" "$pkgdir/usr/lib/$pkgname/system-setup.sh"
  install -Dm644 "packaging/duck-keyboard.desktop" "$pkgdir/etc/xdg/autostart/duck-keyboard.desktop"
  install -Dm644 "README.md" "$pkgdir/usr/share/doc/$pkgname/README.md"
}
