pkgname=duck-keyboard
pkgver=0.1.0
pkgrel=1
pkgdesc="A prank keyboard that plays random duck sounds on every keystroke"
arch=('x86_64')
url="https://github.com/andexer/duck-keyboard"
license=('MIT')
depends=('glibc' 'gcc-libs')
makedepends=('cargo')
source=("duck-keyboard-$pkgver.tar.gz") # Asume el empaquetado del repo
sha256sums=('SKIP')

build() {
  cd "$pkgname-$pkgver"
  cargo build --release --locked
}

package() {
  cd "$pkgname-$pkgver"
  install -Dm755 "target/release/duck-keyboard" "$pkgdir/usr/bin/duck-keyboard"
  install -Dm644 "duck-keyboard.service" "$pkgdir/usr/lib/systemd/system/duck-keyboard.service"
}
