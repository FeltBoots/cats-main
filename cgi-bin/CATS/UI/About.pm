package CATS::UI::About;

use strict;
use warnings;

use CATS::DB;
use CATS::Globals qw($t);
use CATS::Judge;
use CATS::Messages qw(res_str);
use CATS::Output qw(init_template);

sub about_frame {
    my ($p) = @_;
    init_template($p, 'about.html.tt');
    my $problem_count = $dbh->selectrow_array(q~
        SELECT COUNT(*) FROM problems P INNER JOIN contests C ON C.id = P.contest_id
            WHERE C.is_hidden = 0 OR C.is_hidden IS NULL~);
    my $queue_length = $dbh->selectrow_array(qq~
        SELECT COUNT(*) FROM reqs R
            WHERE R.state = $cats::st_not_processed AND R.submit_time > CURRENT_TIMESTAMP - 30~);
    my ($jactive, $jtotal) = CATS::Judge::get_active_count;
    $t->param(
        problem_count => $problem_count,
        queue_length => $queue_length,
        judges_active => $jactive,
        judges_total => $jtotal,
        title_suffix => res_str(1000),
    );
}

1;
