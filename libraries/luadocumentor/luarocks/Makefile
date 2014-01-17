VERSION=0
REVISION=0
# With an ending "/"
URL=http://0.0.0.0:8000/
ROCKSPEC=luadocumentor-${VERSION}-${REVISION}.rockspec
ROCK=luadocumentor-${VERSION}-${REVISION}.tar.gz

.PHONY:clean rockspec

all: rock

rockspec: ${ROCKSPEC}
rock: ${ROCK}

${ROCKSPEC}:
	@echo 'Creating ${ROCKSPEC}'
	@cp luadocumentor-V-R.rockspec ${ROCKSPEC}
	@sed -i 's|V-R|${VERSION}-${REVISION}|' ${ROCKSPEC}
	@sed -i 's|URL|${URL}${ROCK}|' ${ROCKSPEC}

copy:
	@echo 'Importing libraries'
	@cp -r ../../modelsbuilder/models/ \
	  ../../doctemplates/template/ \
	  ../../templateengine/templateengine.lua \
	  .

	@echo 'Copying luadocumentor files'
	@cp -r ../defaultcss.lua ../docgenerator.lua ../extractors.lua \
	  ../lddextractor.lua ../luadocumentor.lua ../fs/ ../template/ \
	  .

${ROCK}: copy rockspec
	@echo 'Inflating ${ROCK}'
	@tar -zcf ${ROCK} ${ROCKSPEC} fs/ models/ template/ \
	  templateengine.lua defaultcss.lua docgenerator.lua \
	  extractors.lua lddextractor.lua luadocumentor.lua
	@echo 'Enjoy ${ROCK}'

clean:
	-@rm -fr fs/ models/ template/ defaultcss.lua docgenerator.lua \
	  extractors.lua lddextractor.lua luadocumentor.lua templateengine.lua \
	  ${ROCKSPEC} ${ROCK}