package CATS::References;

use strict;
use warnings;

use CATS::Globals qw($is_jury $is_root $t $user);
use CATS::Messages qw(res_str);
use CATS::Output qw(url_f);

sub reference_names() {
    (
        { name => 'compilers', new => 542, item => 517 },
        { name => 'judges', new => 512, item => 511 },
        { name => 'keywords', new => 550, item => 549 },
        { name => 'import_sources', item => 557 },
        ($user->is_root ? { name => 'prizes', item => 565 } : ()),
        ($user->is_root ? { name => 'contact_types', new => 587, item => 586 } : ()),
        ($user->privs->{edit_wiki} ? { name => 'wiki_pages', new => 590, item => 589 } : ()),
        ($is_jury ? { name => 'snippets', new => 592, item => 591 } : ()),
        ($user->privs->{edit_sites} ? { name => 'sites', new => 514, item => 513 } : ()),
        ($user->is_root ? { name => 'account_tokens', item => 516 } : ()),
        ($is_jury ? { name => 'contest_tags', new => 405, item => 404 } : ()),
        ($user->is_root ? { name => 'de_tags', new => 403, item => 402 } : ()),
        ($user->is_root ? { name => 'files', new => 401, item => 570 } : ()),
        ($user->is_root ? { name => 'acc_groups', new => 409, item => 410 } : ()),
    )
}

sub menu {
    my ($ref_name) = @_;

    my @result;
    for (reference_names()) {
        my $sel = $_->{name} eq $ref_name;
        push @result,
            { href => url_f($_->{name}), item => res_str($_->{item}), selected => $sel };
        if ($sel && ($user->is_root || $_->{name} eq 'sites' && $user->privs->{edit_sites}) && $_->{new}) {
            unshift @result,
                { href => url_f($_->{name} . '_edit'), item => res_str($_->{new}), new => 1 };
        }
        $t->param(title_suffix => res_str($_->{item})) if $sel;
    }
    @result;
}

1;
