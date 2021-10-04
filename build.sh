#!/bin/sh

# usage:
# buid (to:)<dir>

BUILD_SRC="${1:-index.adoc}"
BUILD_DIR="${2:-_site}"

BUILD_OUTFILE="${BUILD_OUTFILE:-index.html}"
BUILD_PORT="${BUILD_PORT:-5123}"
BUILD_CUSTOMCSS="${BUILD_CUSTOMCSS:-presentation.css}"
REAVEALJS_VERSION="${REAVEALJS_VERSION:-3.9.2}"
BUILD_REVEALJS_DIR="reveal.js-${REAVEALJS_VERSION}"


if [ ! -d "${BUILD_DIR}" ]; then
    mkdir -p "${BUILD_DIR}"
fi
# rm -Rf "${BUILD_DIR}"/*


build()
{
    case "$BUILD_CUSTOMCSS" in
        /*|[a-z]*)
            BUILD_CUSTOMCSS_DIR="$(dirname ${BUILD_CUSTOMCSS})"
            mkdir -p "${BUILD_DIR}/${BUILD_CUSTOMCSS_DIR}/"
            cp "$BUILD_CUSTOMCSS" "${BUILD_DIR}/${BUILD_CUSTOMCSS_DIR}/"
            ;;
    esac

    bundle exec asciidoctor-revealjs \
           -a revealjsdir="${BUILD_REVEALJS_DIR}" \
           -o "${BUILD_OUTFILE}" \
           -a customcss="${BUILD_CUSTOMCSS}" \
           -D "${BUILD_DIR}" \
           "${BUILD_SRC}"
}

build_background()
(
    if ! pgrep -F build.pid >/dev/null 2>/dev/null; then
        inotifywait -m -e close_write *.adoc |
            while read events; do
                echo $events
                build
            done &
        echo $! > build.pid
    fi
)

httpd_start()
{
    if ! pgrep -F httpd.pid >/dev/null 2>/dev/null; then
        ruby -run -ehttpd "${BUILD_DIR}" -p "${BUILD_PORT}" &
        echo $! > httpd.pid
    fi
}

browse_build()
{
    if [ -n "$DISPLAY" ]; then
        firefox "http://localhost:${BUILD_PORT}" >/dev/null &
    fi
}

build_gemfile()
{
    if [ ! -r "Gemfile" ]; then
        cat <<EOF > Gemfile
source 'https://rubygems.org'

gem 'asciidoctor-revealjs', '~> 4.1'
gem 'rouge', '~> 3.26'
EOF
    fi

    bundle
}

build_revealjs()
{
    if [ ! -d "${BUILD_DIR}/${BUILD_REVEALJS_DIR}" ]; then
        curl -L "https://github.com/hakimel/reveal.js/archive/${REAVEALJS_VERSION}.tar.gz" | tar -C "${BUILD_DIR}" -xz
    fi
}

build_gemfile &&
    build_revealjs &&
    build &&
    httpd_start &&
    browse_build &&
    build_background
