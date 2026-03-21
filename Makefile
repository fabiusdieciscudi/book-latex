empty       :=
space       := $(empty) $(empty)
TITLE_ESC   := $(subst $(space),\ ,$(TITLE))

TARGET      := target
DEBUG       := # --debug

MAIN_TEX    := "$(TITLE_ESC).tex"
MAIN_PDF    := "$(TARGET)/$(TITLE_ESC).pdf"
NOTES_TEX   := "Note di lavoro.tex"
NOTES_PDF   := "$(TARGET)/Note di lavoro.pdf"

HTML_DIR    := $(TARGET)/$(subst ",,$(subst $(space),_,$(TITLE)))-epub/OEBPS
HTML2_DIR   := $(TARGET)/Note_di_lavoro-epub/OEBPS
TXT_DIR     := $(TARGET)/txt

TEX_FILES   := $(wildcard *.tex)
# TEX_FILES := $(shell find . -maxdepth 1 -name '*.tex' ! -name '.*')
HTML_FILES  := $(wildcard $(HTML_DIR)/*.html)
HTML2_FILES := $(wildcard $(HTML2_DIR)/*.html)
TXT_FILES   := $(patsubst $(HTML_DIR)/%.html,$(TXT_DIR)/%.txt,$(HTML_FILES)) $(patsubst $(HTML2_DIR)/%.html,$(TXT_DIR)/%.txt,$(HTML2_FILES))
space_to_underscore = $(subst $(space),_,$(notdir $1))

all: pdf

prepare: $(TARGET)
	@$(MAKE) post-clean
	@ln -sf "$(PWD)"/*.tex $(TARGET)/
	@cd $(TARGET) && ln -sf ../book-latex
	@cd $(TARGET) && ln -sf ../illustrazioni
	@cd $(TARGET) && ln -sf ../comuni
	@cd $(TARGET) && ln -sf ../fonts
	@cd $(TARGET) && ln -sf ../frammenti
	@cd $(TARGET) && ln -sf "../note di lavoro"

spellcheck: txt-spell
	BookAssistant spellcheck $(DEBUG) --dict config/Dizionario.txt --dict Dizionario.txt target/txt-spellcheck

check-guillemets: txt-spell
	BookAssistant check-guillemets $(DEBUG) target/txt-spellcheck

echo-check: txt-spell
	BookAssistant echo $(DEBUG) target/txt-spellcheck

stats: txt
	BookAssistant stats $(TARGET)/txt --latex-toc $(TARGET)/$(TITLE).toc

################################ PDF ###########################################################################################################################
pdf: prepare
	cd $(TARGET) && lualatex '\def\purpose{pdf}\input{"$(TITLE).tex"}' && lualatex '\def\purpose{pdf}\input{"$(TITLE).tex"}'
	cd $(TARGET) && lualatex '\def\purpose{pdf}\input{"$(NOTES_TEX)"}' && lualatex '\def\purpose{pdf}\input{"$(NOTES_TEX)"}'
	@$(MAKE) post-clean

################################ EPUB, XHTML, TXT FILES ########################################################################################################
#epub: prepare
#	$(MAKE) post-clean
#	cd $(TARGET) && tex4ebook -l -c ../book-latex/tex4ebook.cfg $(MAIN_TEX)
#	cd $(TARGET) && tex4ebook -l -c ../book-latex/tex4ebook.cfg $(NOTES_TEX)
#	$(MAKE) post-clean
#
################################ TXT FILES #####################################################################################################################
HTML_DIR    	:= $(TARGET)/html
HTML_FILES 		:= $(wildcard $(HTML_DIR)/*.html)
TXT_DIR    		:= $(TARGET)/txt
TXT_FILES  		:= $(patsubst $(HTML_DIR)/%.html,$(TXT_DIR)/%.txt,$(HTML_FILES))

txt: html
	mkdir -p $(TXT_DIR)
	@$(MAKE) txt-files
	@$(MAKE) post-clean

txt-files: $(TXT_FILES)
	@true

html: prepare
	@mkdir -p $(HTML_DIR)
	make4ht -l -c book-latex/make4ht-txt.cfg -d $(HTML_DIR) -B $(HTML_DIR) $(MAIN_TEX) "xhtml" " -cunihtf -utf8" ""

# È necessario il passo intermedio in HTML perché html2txt non tocca i file non modificati.
# Questo fa sì che al passaggio successivo vengano rigenerati solo i file audio necessario.
.INTERMEDIATE:
$(TXT_DIR)/%.txt: $(HTML_DIR)/%.html
	@./book-latex/html2txt.py $< $@

################################ TXT SPELLCHECK FILES ##########################################################################################################
HTML_SPELL_DIR   := $(TARGET)/html-spellcheck
HTML_SPELL_FILES := $(wildcard $(HTML_SPELL_DIR)/*.html)
TXT_SPELL_DIR    := $(TARGET)/txt-spellcheck
TXT_SPELL_FILES  := $(patsubst $(HTML_SPELL_DIR)/%.html,$(TXT_SPELL_DIR)/%.txt,$(HTML_SPELL_FILES))

txt-spell: html-spell
	$(MAKE) txt-spell-files
	$(MAKE) post-clean

txt-spell-files: $(TXT_SPELL_FILES)
	@true

html-spell: prepare
	@mkdir -p $(HTML_SPELL_DIR)
	make4ht -l -c book-latex/make4ht-spellcheck.cfg -d $(HTML_SPELL_DIR) -B $(HTML_SPELL_DIR) $(MAIN_TEX) "xhtml" " -cunihtf -utf8" ""

# È necessario il passo intermedio in HTML perché html2txt non tocca i file non modificati.
# Questo fa sì che al passaggio successivo vengano rigenerati solo i file audio necessario.
.INTERMEDIATE:
$(TXT_SPELL_DIR)/%.txt: $(HTML_SPELL_DIR)/%.html
	@./book-latex/html2txt.py $< $@

################################ TXT AUDIO FILES ###############################################################################################################
HTML_AUDIO_DIR   := $(TARGET)/html-audio
HTML_AUDIO_FILES := $(wildcard $(HTML_AUDIO_DIR)/*.html)
TXT_AUDIO_DIR    := $(TARGET)/txt-audio
TXT_AUDIO_FILES  := $(patsubst $(HTML_AUDIO_DIR)/%.html,$(TXT_AUDIO_DIR)/%.txt,$(HTML_AUDIO_FILES))

txt-audio: html-audio
	@$(MAKE) txt-audio-files
	@$(MAKE) post-clean

txt-audio-files: $(TXT_AUDIO_FILES)
	@true

html-audio: prepare
	@mkdir -p $(HTML_AUDIO_DIR)
	-make4ht -l -c book-latex/make4ht-audio.cfg -d $(HTML_AUDIO_DIR) -B $(HTML_AUDIO_DIR) $(MAIN_TEX) "xhtml" " -cunihtf -utf8" ""

# È necessario il passo intermedio in HTML perché html2txt non tocca i file non modificati.
# Questo fa sì che al passaggio successivo vengano rigenerati solo i file audio necessario.
.INTERMEDIATE:
$(TXT_AUDIO_DIR)/%.txt: $(HTML_AUDIO_DIR)/%.html
	@./book-latex/html2txt.py $< $@

################################ AUDIO #########################################################################################################################
AUDIO_DIR   := $(TARGET)/audio
AUDIO_FILES = $(patsubst $(TXT_AUDIO_DIR)/%.txt,$(AUDIO_DIR)/%.mp3,$(wildcard $(TXT_AUDIO_DIR)/*.txt))

audio: txt-audio
	@$(MAKE) audio-files
	@$(MAKE) post-clean

audio-files: $(AUDIO_FILES)
	@true

$(AUDIO_DIR)/%.mp3: $(TXT_AUDIO_DIR)/%.txt
	@mkdir -p $(AUDIO_DIR)
	@echo "Generating $@ ..."
	BookAssistant tts $(DEBUG) --qwen3-clone-config $(CLONED_VOICES)/qwen3-clones.conf --instruct-config config/instruct.conf $(patsubst %,--voices-config %,$(filter-out config/voices-hq%.conf,$(wildcard config/voices*.conf))) $(patsubst %,--word-patches %,$(wildcard config/word-patches*.conf)) --format mp3 --output $@ $<

################################ HQ AUDIO ######################################################################################################################
HQ_AUDIO_DIR   := $(TARGET)/audio-hq
HQ_AUDIO_FILES = $(patsubst $(TXT_AUDIO_DIR)/%.txt,$(HQ_AUDIO_DIR)/%.mp3,$(wildcard $(TXT_AUDIO_DIR)/*.txt))

hq-audio: txt-audio
	@$(MAKE) hq-audio-files
	@$(MAKE) post-clean

hq-audio-files: $(HQ_AUDIO_FILES)
	@true

$(HQ_AUDIO_DIR)/%.mp3: $(TXT_AUDIO_DIR)/%.txt
	@mkdir -p $(HQ_AUDIO_DIR)
	@echo "Generating $@ ..."
	BookAssistant tts $(DEBUG) --qwen3-clone-config $(CLONED_VOICES)/qwen3-clones.conf --instruct-config config/instruct.conf $(patsubst %,--voices-config %,$(wildcard config/voices-hq*.conf)) $(patsubst %,--word-patches %,$(wildcard config/word-patches*.conf)) --format mp3 --output $@ $<

clean:
	@rm -rfv $(TARGET)

post-clean:
	@rm -f $(TARGET)/*.{tex,aux,log,out,dvi}
	@rm -f $(TARGET)/*.{4ct,4tc,epub,html,css,idv,lg,ncx,opf,tmp,xdv,xref}

$(TARGET):
	@mkdir -p $(TARGET)

.PHONY: all txt clean post-clean install