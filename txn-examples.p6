#!/usr/bin/env perl6
use v6;

subset PkgSrc of IO::Path where { .d && .extension ~~ /pkg|src/ }
subset Tarballish of IO::Path where { .f && .extension ~~ /gz|xz/ }

sub gen-target-dirs(--> Array[IO::Path:D])
{
    my Str:D @ignore = qw<
        .git
        .hg
        .peru
        .subgit
        .subhg
    >;
    my IO::Path:D @dir = dir('.').grep({ .d }).grep(none(@ignore));
}

sub clean-target-dirs(IO::Path:D @dir --> Nil)
{
    await @dir.map(-> IO::Path:D $dir {
        start clean-target-dir($dir);
    });
}

sub clean-target-dir(IO::Path:D $dir --> Nil)
{
    dir($dir).grep(Tarballish).map({ .unlink });
    dir($dir).grep(PkgSrc).map({ .&rm-rf });
}

sub rm-rf(IO::Path:D $dir --> Nil)
{
    dir($dir).grep({ .d }).map({ .&rm-rf });
    dir($dir).grep({ .f }).map({ .unlink });
    rmdir($dir);
}

sub mktarballs(IO::Path:D @dir --> Nil)
{
    await @dir.map(-> IO::Path:D $dir {
        start mktarball($dir);
    });
}

sub mktarball(IO::Path:D $dir --> Nil)
{
    my Str:D $tarball-name = sprintf(Q{%s.tar.gz}, $dir);
    my Str:D $tarball-dest = sprintf(Q{%s/%s}, $dir, $tarball-name);
    run(qqw<tar --exclude=PKGBUILD -czf $tarball-name $dir>);
    rename($tarball-name, $tarball-dest);
}

sub test-target-dirs(
    IO::Path:D @dir,
    *%opts (
        Bool :pacman($)
    )
    --> Hash[Bool:D,IO::Path:D]
)
{
    my Bool:D @test =
        await @dir.map(-> IO::Path:D $dir {
            start test-target-dir($dir, |%opts);
        });
    my Bool:D %test{IO::Path:D} = @dir Z=> @test;
}

multi sub test-target-dir(
    IO::Path:D $dir,
    Bool:D :pacman($)! where .so
    --> Bool:D
)
{
    my Bool:D $passed =
        indir($dir, {
            run(qw<updpkgsums>);
            my Proc:D $makepkg = run(qw<makepkg -Acs -f>);
            my Bool:D $success = $makepkg.exitcode == 0;
        });
}

multi sub test-target-dir(
    IO::Path:D $dir,
    Bool :pacman($)
    --> Bool:D
)
{
    my Bool:D $passed =
        indir($dir, {
            my Proc:D $just = run(qw<just>);
            my Bool:D $success = $just.exitcode == 0;
        });
}

multi sub format(Bool:D %test --> Str:D)
{
    my IO::Path:D @dir = %test.keys;
    my UInt:D $longest = gen-longest-dir-name-length(@dir);
    my Str:D $header = do {
        my Str:D $left = 'dir';
        my Str:D $right = 'result';
        my Str:D $table-row = gen-table-row($left, $right, $longest);
    };
    my Str:D $header-separator = do {
        my Str:D $left = '-' x 3;
        my Str:D $right = '-' x 3;
        my Str:D $table-row = gen-table-row($left, $right, $longest);
    };
    my Str:D $body =
        %test.sort.map(-> %t {
            my Str:D $dir = ~%t.keys.first;
            my Bool:D $success = %t.values.first;
            my Str:D $passed = format($success);
            my Str:D $table-row = gen-table-row($dir, $passed, $longest);
        }).join("\n");
    my Str:D $format = join("\n", $header, $header-separator, $body);
}

multi sub format(Bool:D $success where .so --> Str:D)
{
    my Str:D $format = 'OK';
}

multi sub format(Bool:D $success where .not --> Str:D)
{
    my Str:D $format = 'not OK';
}

sub gen-longest-dir-name-length(IO::Path:D @dir --> UInt:D)
{
    my UInt:D $longest = @dir.map({ .chars }).max;
}

sub gen-table-row(Str:D $left, Str:D $right, UInt:D $longest --> Str:D)
{
    my UInt:D $padding = $longest - $left.chars + 1;
    my Str:D $ws = ' ' x $padding;
    my Str:D $separator = '|';
    my Str:D $table-row = sprintf(Q{%s%s%s %s}, $left, $ws, $separator, $right);
}

sub output(Bool:D %test --> Nil)
{
    my Str:D $output = format(%test);
    say('-' x 72);
    say($output);
    say('-' x 72);
}

multi sub MAIN('clean' --> Nil)
{
    my IO::Path:D @dir = gen-target-dirs();
    clean-target-dirs(@dir);
}

multi sub MAIN('help', Str:D $command? --> Nil)
{
    USAGE($command);
}

multi sub MAIN('reup' --> Nil)
{
    my IO::Path:D @dir = gen-target-dirs();
    clean-target-dirs(@dir);
    mktarballs(@dir);
}

multi sub MAIN('test', *%opts (Bool :pacman($)) --> Nil)
{
    my IO::Path:D @dir = gen-target-dirs();
    my Bool:D %test{IO::Path:D} = test-target-dirs(@dir, |%opts);
    output(%test);
}

multi sub USAGE('clean' --> Nil)
{
    constant $HELP = q:to/EOF/.trim;
    Usage:
      ./txn-examples.p6 clean
    EOF
    say($HELP);
}

multi sub USAGE('reup' --> Nil)
{
    constant $HELP = q:to/EOF/.trim;
    Usage:
      ./txn-examples.p6 reup
    EOF
    say($HELP);
}

multi sub USAGE('test' --> Nil)
{
    constant $HELP = q:to/EOF/.trim;
    Usage:
      ./txn-examples.p6 [--pacman] test

    Options:
      --pacman
        run tests with pacman (arch linux)
    EOF
    say($HELP);
}

multi sub USAGE(--> Nil)
{
    constant $HELP = q:to/EOF/.trim;
    Usage:
      ./txn-examples.p6 [-h] <command>

    Options:
      -h, --help
        display this help message

    Commands:
      clean        clean up test directories
      help         show help for subcommands
      reup         prepare test directories for pacman
      test         run tests
    EOF
    say($HELP);
}
