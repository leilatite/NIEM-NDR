

ifeq ($(USE_SAXON_EE),true)
CHECK_DOC_COMMAND_FLAGS += --saxon-ee 
PROCESS_DOC_COMMAND_FLAGS += --saxon-ee
SAXON_COMMAND_FLAGS += -ee -l:on
endif

CHECK_DOC_COMMAND_FLAGS += --catalog=xsd/ndr-examples/xml-catalog.xml
PROCESS_DOC_COMMAND_FLAGS += --catalog=xsd/ndr-examples/xml-catalog.xml

#############################################################################
# project stuff
#

# things you edit
SRC_DIR := src

# things that are derived, but are not directly useful
TMP_DIR := tmp

# where files representing validation states go
VALID_TOKENS_DIR := $(TMP_DIR)/valid-tokens

# things that are useful, but are derived
DEST_DIR := dest

# generated dependencies for things derived from the NDR doc
DEPENDENCIES_MK := $(TMP_DIR)/dependencies.mk

# the NDR document with macros expanded
NDR_DOC_XML := $(TMP_DIR)/ndr-doc.xml

# valid token
NDR_DOC_XML_VALID_T := $(VALID_TOKENS_DIR)/ndr-doc-xml-valid

# The NDR document rendered in HTML
NDR_DOC_HTML := $(DEST_DIR)/ndr-doc.html

# The NDR document rendered in Text
NDR_DOC_TEXT := $(DEST_DIR)/ndr-doc.txt
STRUCTURES_XSD := $(DEST_DIR)/structures.xsd
APPINFO_XSD := $(DEST_DIR)/appinfo.xsd

# The HTML diff of the Text NDR against the last version
NDR_DIFF_HTML := $(DEST_DIR)/ndr-diff.html

NDR_MACROS_M4 := $(SRC_DIR)/ndr-macros.m4

#############################################################################
# TOOLS stuff
#

# Schematron schema for rules about the NDR doc file
RULES_ABOUT_NDR_SCH := $(SRC_DIR)/ndr-rules.sch

#schematron rules about XML catalogs
RULES_ABOUT_XML_CATALOG_SCH_SRC := $(SRC_DIR)/xml-catalog.sch.m4
RULES_ABOUT_XML_CATALOG_SCH := $(patsubst $(SRC_DIR)/%.m4,$(DEST_DIR)/%,$(RULES_ABOUT_XML_CATALOG_SCH_SRC))

CTAS_RULES_SCH_SOURCE := $(SRC_DIR)/ctas-conformant-document.sch
CTAS_RULES_SCH := $(DEST_DIR)/ctas-conformant-document.sch

# Schematron rules for various Conformance Targets
NDR_RULES_CT_REF_SCH := $(DEST_DIR)/ndr-rules-conformance-target-ref.sch
NDR_RULES_CT_EXT_SCH := $(DEST_DIR)/ndr-rules-conformance-target-ext.sch
NDR_RULES_CT_INS_SCH := $(DEST_DIR)/ndr-rules-conformance-target-ins.sch
NDR_RULES_CT_SET_SCH := $(DEST_DIR)/ndr-rules-conformance-target-set.sch
NDR_RULES_SCH := $(NDR_RULES_CT_REF_SCH) $(NDR_RULES_CT_EXT_SCH) $(NDR_RULES_CT_INS_SCH) $(NDR_RULES_CT_SET_SCH)

NIEM_RELEASE_QC_RULES_SCH := $(TMP_DIR)/niem-release-qc-rules.sch

BASE_CATALOG := xsd/catalog.xml
STRICT_CATALOG := xsd/catalog-xmlschema-strict.xml 

LIST_OF_RULES_TXT := $(DEST_DIR)/list-of-rules.txt
LIST_OF_RULES_AS_JAVA_PROPERTIES := $(DEST_DIR)/list-of-rules-as-java-properties.txt

NDR_ID_MAP_XML = $(DEST_DIR)/ndr-id-map.xml

IMAGES_SRC = $(wildcard $(SRC_DIR)/img/*)
IMAGES_TMP = $(patsubst $(SRC_DIR)/%,$(TMP_DIR)/%,$(IMAGES_SRC))

.PHONY: default
default:
	@echo "You probably should not be doing whatever you are doing."

.PHONY: html
html: $(NDR_DOC_HTML)

.PHONY: text
text: $(NDR_DOC_TEXT)

.PHONY: depend
depend: $(DEPENDENCIES_MK)

-include $(DEPENDENCIES_MK)

# order of sources matters here, since it's fed directly to M4
$(NDR_DOC_XML): config-decls.m4 /Users/wr/r/niem/ndr/doc/common-decls.m4 $(NDR_MACROS_M4) $(SRC_DIR)/ndr-doc.xml.m4 
	@ mkdir -p $(dir $@)
	'/opt/local/bin/grm' -f $@
	m4 --prefix-builtins $^ > $@
	@ chmod -w $@
	@ if grep -n 'MACRO' $@; then printf 'ERROR: unresolved M4 macro.\n' >&2; exit 1; else exit 0; fi

$(NDR_DOC_XML_VALID_T): $(NDR_DOC_XML)
	'/Users/wr/working/tools/bin/check-doc' $(CHECK_DOC_COMMAND_FLAGS) $<
	mkdir -p $(dir $@)
	touch $@

tmp/xsd/%: src/xsd/%
	mkdir -p $(dir $@)
	cp $< $@

$(DEPENDENCIES_MK): $(NDR_DOC_XML) $(NDR_DOC_XML_VALID_T)
	'/Users/wr/working/tools/bin/process-doc' $(PROCESS_DOC_COMMAND_FLAGS) -makedepend -in $< -out $@

.PHONY: docs
# put HTML first so it builds first
DOCS_LOCAL := $(NDR_DOC_HTML) $(NDR_RULES_SCH) $(LIST_OF_RULES_TXT) $(CTAS_RULES_SCH) $(NDR_DOC_TEXT) $(LIST_OF_RULES_AS_JAVA_PROPERTIES) $(NDR_ID_MAP_XML) $(RULES_ABOUT_XML_CATALOG_SCH) $(STRUCTURES_XSD) $(APPINFO_XSD)
# Diff file requires SVN access to build
DOCS_HAS_NETWORK := $(NDR_DIFF_HTML)
docs: $(DOCS_LOCAL) $(DOCS_HAS_NETWORK)
docs-local: $(DOCS_LOCAL)

.PHONY: all
all: docs valid 

#############################################################################
# HTML doc

$(NDR_DOC_HTML): $(NDR_DOC_XML) $(NDR_DOC_XML_VALID_T) $(IMAGES_TMP) $(DOC_HTML_REQUIRED_FILES)
	@ mkdir -p $(dir $@)
	'/Users/wr/working/tools/bin/process-doc' $(PROCESS_DOC_COMMAND_FLAGS) -html -in $< -out $@

$(TMP_DIR)/img/%: $(SRC_DIR)/img/%
	'/opt/local/bin/grm' -f $@
	mkdir -p $(dir $@)
	cp $< $@

$(TMP_DIR)/img/%.png.width.txt: $(TMP_DIR)/img/%.png
	identify -format '%w' $< > $@

##################################################################
# TEXT doc

$(NDR_DOC_TEXT): $(NDR_DOC_XML) $(NDR_DOC_XML_VALID_T) $(DOC_TEXT_REQUIRED_FILES)
	@mkdir -p $(dir $@)
	'/Users/wr/working/tools/bin/process-doc' $(PROCESS_DOC_COMMAND_FLAGS) -plaintext -in $< -out $@

.PHONY: diff
diff: $(NDR_DIFF_HTML)
$(NDR_DIFF_HTML): $(NDR_DOC_TEXT)
	'/Users/wr/working/tools/bin/svn-wdiff-html' --verbose --output=$@ $< -r 42801

#############################################################################
# Schematron rules generated off of the doc
#

.PHONY: rules
rules: \
	$(NDR_RULES_CT_REF_SCH) \
	$(NDR_RULES_CT_EXT_SCH) \
	$(NDR_RULES_CT_SET_SCH) \
	$(NDR_RULES_CT_INS_SCH) \
	$(RULES_ABOUT_XML_CATALOG_SCH)

rules-ref ref: $(NDR_RULES_CT_REF_SCH)
rules-ext ext: $(NDR_RULES_CT_EXT_SCH)
rules-ins ins: $(NDR_RULES_CT_INS_SCH)
rules-set set: $(NDR_RULES_CT_SET_SCH)

DOC_TO_SCHEMATRON_XSL_SRC := $(SRC_DIR)/doc-to-schematron.xsl.m4
DOC_TO_SCHEMATRON_XSL := $(DOC_TO_SCHEMATRON_XSL_SRC:$(SRC_DIR)/%.m4=$(TMP_DIR)/%)
DOC_TO_SCHEMATRON_XSL_DEPENDENCIES := /Users/wr/working/tools/share/doc-processing/common.xsl

$(DOC_TO_SCHEMATRON_XSL) : config-decls.m4 /Users/wr/r/niem/ndr/doc/common-decls.m4 src/ndr-macros.m4 $(DOC_TO_SCHEMATRON_XSL_SRC) 
	@ mkdir -p $(dir $@)
	m4 --prefix-builtins $^ > $@

$(NDR_RULES_CT_REF_SCH): $(NDR_DOC_XML) $(DOC_TO_SCHEMATRON_XSL) $(DOC_TO_SCHEMATRON_XSL_DEPENDENCIES)
	@ mkdir -p $(dir $@)
	'/Users/wr/working/tools/bin/saxon' $(SAXON_COMMAND_FLAGS) -xsl $(DOC_TO_SCHEMATRON_XSL) -in $< -out $@ - blurb-set=ref title='Rules for reference XML Schema documents'

$(NDR_RULES_CT_EXT_SCH): $(NDR_DOC_XML) $(DOC_TO_SCHEMATRON_XSL) $(DOC_TO_SCHEMATRON_XSL_DEPENDENCIES)
	@ mkdir -p $(dir $@)
	'/Users/wr/working/tools/bin/saxon' $(SAXON_COMMAND_FLAGS) -xsl $(DOC_TO_SCHEMATRON_XSL) -in $< -out $@ - blurb-set=ext title='Rules for extension XML Schema documents'

$(NDR_RULES_CT_SET_SCH): $(NDR_DOC_XML) $(DOC_TO_SCHEMATRON_XSL) $(DOC_TO_SCHEMATRON_XSL_DEPENDENCIES)
	@ mkdir -p $(dir $@)
	'/Users/wr/working/tools/bin/saxon' $(SAXON_COMMAND_FLAGS) -xsl $(DOC_TO_SCHEMATRON_XSL) -in $< -out $@ - blurb-set=set title='Rules for XML Schema document sets'

$(NDR_RULES_CT_INS_SCH): $(NDR_DOC_XML) $(DOC_TO_SCHEMATRON_XSL) $(DOC_TO_SCHEMATRON_XSL_DEPENDENCIES)
	@ mkdir -p $(dir $@)
	'/Users/wr/working/tools/bin/saxon' $(SAXON_COMMAND_FLAGS) -xsl $(DOC_TO_SCHEMATRON_XSL) -in $< -out $@ - blurb-set=ins title='Rules for instance XML documents'

######################################################################
# support files

$(RULES_ABOUT_XML_CATALOG_SCH): config-decls.m4 /Users/wr/r/niem/ndr/doc/common-decls.m4 $(NDR_MACROS_M4) $(RULES_ABOUT_XML_CATALOG_SCH_SRC)
	mkdir -p $(@D)
	if test -f $@; then chmod 644 $@; fi
	m4 --prefix-builtins $^ > $@
	chmod 444 $@

$(APPINFO_XSD): src/xsd/niem/appinfo/4.0/appinfo.xsd
	rm -f $@
	mkdir -p ${dir $@}
	install -m 444 -T $< $@

$(STRUCTURES_XSD): src/xsd/niem/structures/4.0/structures.xsd
	rm -f $@
	mkdir -p ${dir $@}
	install -m 444 -T $< $@

#############################################################################
# NDR ID Map: map of IDs in the NDR; useful for transforming into stable formats
GET_NDR_ID_MAP_XSL_SRC := $(SRC_DIR)/get-ndr-id-map.xsl.m4
GET_NDR_ID_MAP_XSL := $(GET_NDR_ID_MAP_XSL_SRC:$(SRC_DIR)/%.m4=$(TMP_DIR)/%)
GET_NDR_ID_MAP_XSL_DEPENDENCIES := /Users/wr/working/tools/share/doc-processing/common.xsl 

# order of dependencies is important here, since that's the order that things to to M4.
$(GET_NDR_ID_MAP_XSL): config-decls.m4 /Users/wr/r/niem/ndr/doc/common-decls.m4 src/ndr-macros.m4 $(GET_NDR_ID_MAP_XSL_SRC) 
	@ mkdir -p $(dir $@)
	m4 --prefix-builtins $^ > $@

.PHONY: map
map: $(NDR_ID_MAP_XML)
$(NDR_ID_MAP_XML):  $(NDR_DOC_XML) $(NDR_DOC_XML_VALID_T) $(GET_NDR_ID_MAP_XSL)
	'/Users/wr/working/tools/bin/saxon' $(SAXON_COMMAND_FLAGS) -xsl $(GET_NDR_ID_MAP_XSL) -in $< -out $@

#############################################################################
# list of rules

GET_LIST_OF_RULES_FROM_NDR_XSL_SRC := $(SRC_DIR)/get-list-of-rules-from-ndr.xsl.m4
GET_LIST_OF_RULES_FROM_NDR_XSL := $(GET_LIST_OF_RULES_FROM_NDR_XSL_SRC:$(SRC_DIR)/%.m4=$(TMP_DIR)/%)
GET_LIST_OF_RULES_FROM_NDR_XSL_DEPENDENCIES := /Users/wr/working/tools/share/doc-processing/common.xsl 

# order of dependencies is important here, since that's the order that things to to M4.
$(GET_LIST_OF_RULES_FROM_NDR_XSL) : config-decls.m4 /Users/wr/r/niem/ndr/doc/common-decls.m4 src/ndr-macros.m4 $(GET_LIST_OF_RULES_FROM_NDR_XSL_SRC) 
	@ mkdir -p $(dir $@)
	m4 --prefix-builtins $^ > $@

.PHONY: list
list: $(LIST_OF_RULES_TXT)
$(LIST_OF_RULES_TXT): $(NDR_DOC_XML) $(NDR_DOC_XML_VALID_T) $(GET_LIST_OF_RULES_FROM_NDR_XSL)
	'/Users/wr/working/tools/bin/saxon' $(SAXON_COMMAND_FLAGS) -xsl $(GET_LIST_OF_RULES_FROM_NDR_XSL) -in $< -out $@

.PHONY: jp
jp: $(LIST_OF_RULES_AS_JAVA_PROPERTIES)

$(LIST_OF_RULES_AS_JAVA_PROPERTIES): $(LIST_OF_RULES_TXT) bin/convert-rules-list-to-java-properties
	bin/convert-rules-list-to-java-properties < $< > $@


# list looks good formatted with:
#     expand -t 51,64 < dest/list-of-rules.txt 


#############################################################################
# Quality Control rules

$(NIEM_RELEASE_QC_RULES_SCH) : config-decls.m4 /Users/wr/r/niem/ndr/doc/common-decls.m4 $(NDR_MACROS_M4) $(SRC_DIR)/niem-release-qc-rules.sch 
	m4 --prefix-builtins $^ > $@

#############################################################################
# run M4 on NDR functions

$(CTAS_RULES_SCH): config-decls.m4 /Users/wr/r/niem/ndr/doc/common-decls.m4 $(NDR_MACROS_M4) $(CTAS_RULES_SCH_SOURCE) 
	mkdir -p $(dir $@)
	m4 --prefix-builtins $^ > $@

#############################################################################
# Validations
#############################################################################

# ensure the NDR doc xml is valid against a set of schematron rules for the NDR doc
# the validation works in a temp dir, because it generates tons of intermediate files
V1 := ndr_doc_xml-valid-against-ndr_rules_sch
V1_D := $(TMP_DIR)/$(V1).d
V1_T := $(VALID_TOKENS_DIR)/$(V1)
$(V1_T): $(NDR_DOC_XML) $(NDR_DOC_XML_VALID_T) $(RULES_ABOUT_NDR_SCH)
	mkdir -p $(V1_D)
	cp $(RULES_ABOUT_NDR_SCH) $(V1_D)/ndr-rules.sch
	'/Users/wr/working/tools/bin/schematron' -ee -schema $(V1_D)/ndr-rules.sch $(NDR_DOC_XML)
	mkdir -p $(dir $@)
	touch $@

.PHONY: v1
v1: $(V1_T)

# V2 is dead.

# ensure the NDR doc xml is valid as a doc
V3 := ndr_doc_xml-valid-as-doc
V3_D := $(TMP_DIR)/$(V3).d
V3_T := $(VALID_TOKENS_DIR)/$(V3)
$(V3_T): $(NDR_DOC_XML) $(NDR_DOC_XML_VALID_T)
	mkdir -p $(V3_D)
	'/Users/wr/working/tools/bin/check-doc' $(CHECK_DOC_COMMAND_FLAGS) -t $(V3_D) $<
	mkdir -p $(dir $@)
	touch $@

.PHONY: v3
v3: $(V3_T)

# validate that all generated NDR rules files are schematron
V4 := ndr_rules_sch-valid-as-schematron
V4_D := $(VALID_TOKENS_DIR)/$(V4).d
V4_T := $(patsubst $(DEST_DIR)/%,$(V4_D)/%,$(NDR_RULES_SCH))
$(V4_D)/%: $(DEST_DIR)/%
	'/Users/wr/working/tools/bin/check-schematron' $<
	mkdir -p $(dir $@)
	touch $@
.PHONY: v4
v4: $(V4_T)

# validate that catalog files are valid against the catalog XSD
V5 := v5_catalogs-valid-against-catalog-xsd
V5_D := $(VALID_TOKENS_DIR)/$(V5).d
CATALOGS := $(BASE_CATALOG) $(STRICT_CATALOG)
V5_T := $(patsubst %,$(V5_D)/%,$(CATALOGS))
CATALOG_XSD := xsd/xml-catalog/xml-catalog-1.1.xsd
$(V5_D)/%: % $(CATALOG_XSD) xsd/xml-catalog/catalog.xml
	'/Users/wr/working/tools/bin/xsdvalid' -catalog xsd/xml-catalog/catalog.xml $<
	mkdir -p $(dir $@)
	touch $@
.PHONY: v5
v5: $(V5_T)

info:
	printf 'V5_T: "%s"\n' $(V5_T)
	printf $(V5_D)/%: % $(CATALOG_XSD) xsd/catalog-for-catalog.xml



.PHONY: valid
valid: $(V3_T) $(V1_T) $(V4_T) $(V5_T)

#############################################################################
# Misc conveniences

ARCHIVE_NAME := NIEM-NDR-4.0beta1-2017-03-31
archive: tmp/$(ARCHIVE_NAME).html
	'/opt/local/bin/grm' -rf tmp/$(ARCHIVE_NAME)
	'/opt/local/bin/grm' -f tmp/$(ARCHIVE_NAME).zip
	'/opt/local/bin/gmkdir' tmp/$(ARCHIVE_NAME)
	'/usr/bin/rsync' -Parv dest/ tmp/$(ARCHIVE_NAME)/
	'/opt/local/bin/grm' -f tmp/$(ARCHIVE_NAME)/xml-catalog.sch
	'/opt/local/bin/grm' -f tmp/$(ARCHIVE_NAME)/list-of-rules.txt
	cd tmp; '/usr/bin/zip' -r -9 $(ARCHIVE_NAME).zip $(ARCHIVE_NAME)

tmp/$(ARCHIVE_NAME).html: dest/ndr-doc.html
	cp $< $@



