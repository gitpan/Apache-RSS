#include "modules/perl/mod_perl.h"

static mod_perl_perl_dir_config *newPerlConfig(pool *p)
{
    mod_perl_perl_dir_config *cld =
	(mod_perl_perl_dir_config *)
	    palloc(p, sizeof (mod_perl_perl_dir_config));
    cld->obj = Nullsv;
    cld->pclass = "Apache::RSS";
    register_cleanup(p, cld, perl_perl_cmd_cleanup, null_cleanup);
    return cld;
}

static void *create_dir_config_sv (pool *p, char *dirname)
{
    return newPerlConfig(p);
}

static void *create_srv_config_sv (pool *p, server_rec *s)
{
    return newPerlConfig(p);
}

static void stash_mod_pointer (char *class, void *ptr)
{
    SV *sv = newSV(0);
    sv_setref_pv(sv, NULL, (void*)ptr);
    hv_store(perl_get_hv("Apache::XS_ModuleConfig",TRUE), 
	     class, strlen(class), sv, FALSE);
}

static mod_perl_cmd_info cmd_info_RSSEnableRegexp = { 
"Apache::RSS::RSSEnableRegexp", "", 
};
static mod_perl_cmd_info cmd_info_RSSChannelTitle = { 
"Apache::RSS::RSSChannelTitle", "", 
};
static mod_perl_cmd_info cmd_info_RSSChannelDescription = { 
"Apache::RSS::RSSChannelDescription", "", 
};
static mod_perl_cmd_info cmd_info_RSSCopyRight = { 
"Apache::RSS::RSSCopyRight", "", 
};
static mod_perl_cmd_info cmd_info_RSSEncoding = { 
"Apache::RSS::RSSEncoding", "", 
};
static mod_perl_cmd_info cmd_info_RSSLanguage = { 
"Apache::RSS::RSSLanguage", "", 
};
static mod_perl_cmd_info cmd_info_RSSScanHTMLTitle = { 
"Apache::RSS::RSSScanHTMLTitle", "", 
};
static mod_perl_cmd_info cmd_info_RSSHTMLRegexp = { 
"Apache::RSS::RSSHTMLRegexp", "", 
};
static mod_perl_cmd_info cmd_info_RSSEncodeHandler = { 
"Apache::RSS::RSSEncodeHandler", "", 
};


static command_rec mod_cmds[] = {
    
    { "RSSEnableRegexp", perl_cmd_perl_TAKE1,
      (void*)&cmd_info_RSSEnableRegexp,
      OR_INDEXES, TAKE1, "1-3 value(s) for RSSEnableRegexp" },

    { "RSSChannelTitle", perl_cmd_perl_TAKE1,
      (void*)&cmd_info_RSSChannelTitle,
      OR_INDEXES, TAKE1, "1-3 value(s) for RSSChannelTitle" },

    { "RSSChannelDescription", perl_cmd_perl_TAKE1,
      (void*)&cmd_info_RSSChannelDescription,
      OR_INDEXES, TAKE1, "1-3 value(s) for RSSChannelDescription" },

    { "RSSCopyRight", perl_cmd_perl_TAKE1,
      (void*)&cmd_info_RSSCopyRight,
      OR_INDEXES, TAKE1, "1-3 value(s) for RSSCopyRight" },

    { "RSSEncoding", perl_cmd_perl_TAKE1,
      (void*)&cmd_info_RSSEncoding,
      OR_INDEXES, TAKE1, "1-3 value(s) for RSSEncoding" },

    { "RSSLanguage", perl_cmd_perl_TAKE1,
      (void*)&cmd_info_RSSLanguage,
      OR_INDEXES, TAKE1, "1-3 value(s) for RSSLanguage" },

    { "RSSScanHTMLTitle", perl_cmd_perl_FLAG,
      (void*)&cmd_info_RSSScanHTMLTitle,
      OR_INDEXES, FLAG, "1-3 value(s) for RSSScanHTMLTitle" },

    { "RSSHTMLRegexp", perl_cmd_perl_TAKE1,
      (void*)&cmd_info_RSSHTMLRegexp,
      OR_INDEXES, TAKE1, "1-3 value(s) for RSSHTMLRegexp" },

    { "RSSEncodeHandler", perl_cmd_perl_TAKE1,
      (void*)&cmd_info_RSSEncodeHandler,
      OR_INDEXES, TAKE1, "1-3 value(s) for RSSEncodeHandler" },

    { NULL }
};

module MODULE_VAR_EXPORT XS_Apache__RSS = {
    STANDARD_MODULE_STUFF,
    NULL,               /* module initializer */
    create_dir_config_sv,  /* per-directory config creator */
    NULL,   /* dir config merger */
    create_srv_config_sv,       /* server config creator */
    NULL,        /* server config merger */
    mod_cmds,               /* command table */
    NULL,           /* [7] list of handlers */
    NULL,  /* [2] filename-to-URI translation */
    NULL,      /* [5] check/validate user_id */
    NULL,       /* [6] check user_id is valid *here* */
    NULL,     /* [4] check access by host address */
    NULL,       /* [7] MIME type checker/setter */
    NULL,        /* [8] fixups */
    NULL,             /* [10] logger */
    NULL,      /* [3] header parser */
    NULL,         /* process initializer */
    NULL,         /* process exit/cleanup */
    NULL,   /* [1] post read_request handling */
};

#define this_module "Apache/RSS.pm"

static void remove_module_cleanup(void *data)
{
    if (find_linked_module("Apache::RSS")) {
        /* need to remove the module so module index is reset */
        remove_module(&XS_Apache__RSS);
    }
    if (data) {
        /* make sure BOOT section is re-run on restarts */
        (void)hv_delete(GvHV(incgv), this_module,
                        strlen(this_module), G_DISCARD);
         if (dowarn) {
             /* avoid subroutine redefined warnings */
             perl_clear_symtab(gv_stashpv("Apache::RSS", FALSE));
         }
    }
}

MODULE = Apache::RSS		PACKAGE = Apache::RSS

PROTOTYPES: DISABLE

BOOT:
    XS_Apache__RSS.name = "Apache::RSS";
    add_module(&XS_Apache__RSS);
    stash_mod_pointer("Apache::RSS", &XS_Apache__RSS);
    register_cleanup(perl_get_startup_pool(), (void *)1,
                     remove_module_cleanup, null_cleanup);

void
END()

    CODE:
    remove_module_cleanup(NULL);
