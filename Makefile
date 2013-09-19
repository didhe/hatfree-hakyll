MAIN = `pwd | sed 's/-hakyll$$//'`

main: build

site: site.hs
	ghc --make site -Wall

clean: site
	./site clean
	rm site site.hi site.o

build: site
	./site build

check: site
	./site check

preview: rebuild
	./site preview

rebuild: site
	./site rebuild

server: site
	./site server

post:
	zsh -c '\
		prompt() { echo -n "$$1:\t" >&2; read $$1 }; \
		for ea in title author; do prompt $$ea; done; \
		id=`perl -E"for(lc pop){s/[^a-z]+/-/ig;s/^-*|-*$$//;say}" "$$title"`; \
		file=posts/$$(date +%F)-$$id.markdown; \
		(echo ---; \
		echo title: $$title; \
		echo author: $$author; \
		echo ---; \
		echo; echo) > $$file; \
		hg add -v $$file; \
		vim +$$ $$file'

deploy: _site/.hg

_site/.hg: site
	./site clean
	hg clone $(MAIN) _site
	(cd _site; hg up -r gh-pages)
	./site build
	(cd _site; hg ci -A && hg push)

publish: deploy
	(cd $(MAIN); hg push)

.PHONY: build check clean preview rebuild server post
