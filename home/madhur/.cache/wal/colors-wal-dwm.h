static const char norm_fg[] = "#f3f4f5";
static const char norm_bg[] = "#1c2023";
static const char norm_border[] = "#747c84";

static const char sel_fg[] = "#f3f4f5";
static const char sel_bg[] = "#95c7ae";
static const char sel_border[] = "#f3f4f5";

static const char urg_fg[] = "#f3f4f5";
static const char urg_bg[] = "#c7ae95";
static const char urg_border[] = "#c7ae95";

static const char *colors[][3]      = {
    /*               fg           bg         border                         */
    [SchemeNorm] = { norm_fg,     norm_bg,   norm_border }, // unfocused wins
    [SchemeSel]  = { sel_fg,      sel_bg,    sel_border },  // the focused win
    [SchemeUrg] =  { urg_fg,      urg_bg,    urg_border },
};
