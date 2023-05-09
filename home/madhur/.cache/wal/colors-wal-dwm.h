static const char norm_fg[] = "#fafdff";
static const char norm_bg[] = "#1c252c";
static const char norm_border[] = "#384148";

static const char sel_fg[] = "#fafdff";
static const char sel_bg[] = "#78DBA9";
static const char sel_border[] = "#fafdff";

static const char urg_fg[] = "#fafdff";
static const char urg_bg[] = "#e05f65";
static const char urg_border[] = "#e05f65";

static const char *colors[][3]      = {
    /*               fg           bg         border                         */
    [SchemeNorm] = { norm_fg,     norm_bg,   norm_border }, // unfocused wins
    [SchemeSel]  = { sel_fg,      sel_bg,    sel_border },  // the focused win
    [SchemeUrg] =  { urg_fg,      urg_bg,    urg_border },
};
