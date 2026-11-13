#!/bin/bash
# usage: build.sh <repo-root>   (concatenates common + optional cards + game + footer into <repo-root>/<folder>/startup.lua)
set -e
SRC="$(cd "$(dirname "$0")" && pwd)"
OUT="$1"
build() { # folder gamefile usesCards
    mkdir -p "$OUT/$1"
    {
        cat "$SRC/common.lua"
        [ "$3" = "cards" ] && cat "$SRC/cards.lua"
        cat "$SRC/games/$2"
        cat "$SRC/footer.lua"
    } > "$OUT/$1/startup.lua"
    cp "$SRC/casinoSettings.lua" "$OUT/$1/casinoSettings.lua"
    echo "built $1/startup.lua ($(wc -l < "$OUT/$1/startup.lua") lines)"
}
for f in slots:slots.lua texasHoldem:texasHoldem.lua:cards baccarat:baccarat.lua:cards \
         villagerRaces:villagerRaces.lua plinko:plinko.lua craps:craps.lua; do
    IFS=: read -r folder file cards <<< "$f"
    [ -f "$SRC/games/$file" ] && build "$folder" "$file" "$cards"
done
mkdir -p "$OUT/tos"
cp "$SRC/tos.lua" "$OUT/tos/startup.lua"
cp "$SRC/casinoSettings.lua" "$OUT/tos/casinoSettings.lua"
echo "built tos/startup.lua ($(wc -l < "$OUT/tos/startup.lua") lines)"
cp "$SRC/casinoSettings.lua" "$OUT/casinoSettings.lua"
exit 0
