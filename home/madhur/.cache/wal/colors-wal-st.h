const char *colorname[] = {

  /* 8 normal colors */
  [0] = "#1c252c", /* black   */
  [1] = "#e05f65", /* red     */
  [2] = "#78DBA9", /* green   */
  [3] = "#f1cf8a", /* yellow  */
  [4] = "#70a5eb", /* blue    */
  [5] = "#c68aee", /* magenta */
  [6] = "#74bee9", /* cyan    */
  [7] = "#dee1e6", /* white   */

  /* 8 bright colors */
  [8]  = "#384148",  /* black   */
  [9]  = "#fc7b81",  /* red     */
  [10] = "#94f7c5", /* green   */
  [11] = "#ffeba6", /* yellow  */
  [12] = "#8cc1ff", /* blue    */
  [13] = "#e2a6ff", /* magenta */
  [14] = "#90daff", /* cyan    */
  [15] = "#fafdff", /* white   */

  /* special colors */
  [256] = "#101419", /* background */
  [257] = "#b6beca", /* foreground */
  [258] = "#f5f5f5",     /* cursor */
};

/* Default colors (colorname index)
 * foreground, background, cursor */
 unsigned int defaultbg = 0;
 unsigned int defaultfg = 257;
 unsigned int defaultcs = 258;
 unsigned int defaultrcs= 258;
