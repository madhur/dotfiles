const gulp = require('gulp');
const shell = require('gulp-shell');

// Task to execute the backup script
gulp.task('backup', shell.task([
    'chmod +x backup.sh',  // Ensure script is executable
    './backup.sh'          // Execute the backup script
], {
    cwd: './',             // Run in current directory
    verbose: true          // Show command output
}));

// Task to add all changes to git (respects .gitignore)
gulp.task('gitadd', shell.task([
    'git add .'
], {
    cwd: './',
    verbose: true
}));

// Task to commit changes. Generates the message through the shared, instrumented
// homelab lib (`homelab-git commit-message`, service="claude_cli" metrics),
// falling back to a timestamped backup message if the LLM call fails or returns
// empty. gitadd has already staged everything before this runs; the CLI reads
// `git diff --staged` from cwd. --source tags the LLM spend as "dotfiles".
gulp.task('gitcommit', shell.task([
    'MSG=$(/home/madhur/.virtualenvs/python-rsha/bin/homelab-git commit-message --source dotfiles 2>/dev/null); ' +
    '[ -z "$MSG" ] && MSG="backup: Dotfiles updated on ' + new Date().toLocaleString('en-IN', { timeZone: 'Asia/Kolkata' }) + ' IST"; ' +
    'git commit -m "$MSG"'
], {
    cwd: './',
    verbose: true
}));

// Task to push to GitHub
gulp.task('gitpush', shell.task([
    'git push origin master'  // Using master as shown in your git status
], {
    cwd: './',
    verbose: true
}));

// Task to check git status (optional, for debugging)
gulp.task('gitstatus', shell.task([
    'git status'
], {
    cwd: './',
    verbose: true
}));

// Combined git tasks
gulp.task('git', gulp.series('gitadd', 'gitcommit', 'gitpush'));

// Main task that runs backup and then pushes to git
gulp.task('backup-and-push', gulp.series('backup', 'git'));

// Alternative task that includes status check for debugging
gulp.task('backup-and-push-verbose', gulp.series('backup', 'gitstatus', 'git'));

// Default task
gulp.task('default', gulp.series('backup-and-push'));