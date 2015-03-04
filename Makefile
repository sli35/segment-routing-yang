I_D = draft-litkowski-spring-sr-yang
REVNO = 00
DATE ?= $(shell date +%F)
MODULES = ietf-segment-routing
FIGURES = ietf-segment-routing.tree \
	  interfaces.tree rpcs.tree notifications.tree
EXAMPLE_BASE = example
EXAMPLE_TYPE = get-config-reply
baty = $(EXAMPLE_BASE)-$(EXAMPLE_TYPE)
EXAMPLE_INST = $(baty).xml
PYANG_OPTS = -p ../isis-yang 

artworks = $(addsuffix .aw, $(yams)) $(EXAMPLE_INST).aw \
	   $(addsuffix .aw, $(FIGURES))
idrev = $(I_D)-$(REVNO)
yams = $(addsuffix .yang, $(MODULES))
xsldir = .tools/xslt
xslpars = --stringparam date $(DATE) --stringparam i-d-name $(I_D) \
	  --stringparam i-d-rev $(REVNO)
schemas = $(baty).rng $(baty).sch $(baty).dsrl
y2dopts = -t $(EXAMPLE_TYPE) -b $(EXAMPLE_BASE)

.PHONY: all validate clean rnc

all: $(idrev).txt $(schemas) summary.tree model.tree

$(idrev).xml: $(I_D).xml $(artworks) figures.ent yang.ent
	@xsltproc $(xslpars) $(xsldir)/upd-i-d.xsl $< | xmllint --noent -o $@ -

$(idrev).txt: $(idrev).xml
	@xml2rfc --dtd=.tools/schema/rfc2629.dtd $<

hello.xml: $(yams) hello-external.ent
	@echo '<hello xmlns="urn:ietf:params:xml:ns:netconf:base:1.0">' > $@
	@echo '<capabilities>' >> $@
	@echo '<capability>urn:ietf:params:netconf:base:1.1</capability>' >> $@
	@for m in $(yams); do \
	  capa=$$(pyang $(PYANG_OPTS) -f capability --capability-entity $$m); \
	  if [ "$$capa" != "" ]; then \
	    echo "<capability>$$capa</capability>" >> $@; \
	  fi \
	done
	@cat hello-external.ent >> $@
	@echo '</capabilities>' >> $@
	@echo '</hello>' >> $@


yang.ent: $(yams)
	@echo '<!-- External entities for files with modules -->' > $@
	@for f in $^; do                                                 \
	  echo '<!ENTITY '"$$f SYSTEM \"$$f.aw\">" >> $@;          \
	done
ifneq ($EXAMPLE_INST,)
	@echo '<!ENTITY '"$(EXAMPLE_INST) SYSTEM \"$(EXAMPLE_INST).aw\">" >> $@
endif

figures.ent: $(FIGURES)
ifeq ($(FIGURES),)
	@touch $@
else
	@echo '<!-- External entities for files with figures -->' > $@; \
	for f in $^; do                                            \
	  echo '<!ENTITY '"$$f SYSTEM \"$$f.aw\">" >> $@;  \
	done
endif

%.yang.aw: %.yang
	@pyang $(PYANG_OPTS) --ietf $<
	@echo '<artwork>' > $@
	@echo '<![CDATA[<CODE BEGINS> file '"\"$*@$(DATE).yang\"" >> $@
	@echo >> $@
	@cat $< >> $@
	@echo >> $@
	@echo '<CODE ENDS>]]></artwork>' >> $@

%.aw: %
	@echo '<artwork><![CDATA[' > $@; \
	cat $< >> $@;                    \
	echo ']]></artwork>' >> $@

$(schemas): hello.xml
	yang2dsdl $(y2dopts) -L $<

%.rnc: %.rng
	trang -I rng -O rnc $< $@

rnc: $(baty).rnc

validate: $(EXAMPLE_INST) $(schemas)
	@yang2dsdl -j -s $(y2dopts) -v $<

model.tree: hello.xml
	pyang $(PYANG_OPTS) -f tree -o $@ -L $<

ietf-segment-routing.tree: $(yams)
	pyang $(PYANG_OPTS) -f tree -o $@ --tree-depth 8 $<

summary.tree: $(yams)
	pyang -f tree -o $@ --tree-depth 3 $<

clean:
	@rm -rf *.rng *.rnc *.sch *.dsrl hello.xml model.tree \
	  ietf-segment-routing-svc.tree $(idrev).* $(artworks) figures.ent yang.ent
