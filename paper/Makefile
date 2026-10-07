# Build the rechaos paper with a Nix-provided TeX Live toolchain.
# `make` -> rechaos.pdf (quick, iterative, uses `nix shell`).
# For a hermetic, cached build use the flake instead:
#     nix build .#paper        # -> result/rechaos.pdf (from repo root)
# No system LaTeX install required either way.

PAPER   := rechaos
H       := \#
TEXPKG  := nixpkgs$(H)texliveMedium
NIXRUN  := nix shell $(TEXPKG) --command

.PHONY: all clean watch

all: $(PAPER).pdf

$(PAPER).pdf: $(PAPER).tex refs.bib
	$(NIXRUN) latexmk -pdf -interaction=nonstopmode -halt-on-error $(PAPER).tex

watch: $(PAPER).tex refs.bib
	$(NIXRUN) latexmk -pdf -pvc -interaction=nonstopmode $(PAPER).tex

clean:
	$(NIXRUN) latexmk -C $(PAPER).tex
	rm -f $(PAPER).bbl $(PAPER).run.xml
