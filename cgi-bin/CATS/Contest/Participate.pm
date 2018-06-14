package CATS::Contest::Participate;

use strict;
use warnings;

use CATS::Constants;
use CATS::DB;
use CATS::Globals qw($cid $contest $is_jury $is_root $uid $user);
use CATS::Messages qw(msg);

use Exporter qw(import);

our @EXPORT_OK = qw(
    get_registered_contestant
    is_jury_in_contest
);

# Params: fields, contest_id, account_id.
sub get_registered_contestant {
    my %p = @_;
    $p{fields} ||= 1;
    $p{account_id} ||= $uid or return;
    $p{contest_id} or die;

    $dbh->selectrow_array(qq~
        SELECT $p{fields} FROM contest_accounts WHERE contest_id = ? AND account_id = ?~, undef,
        $p{contest_id}, $p{account_id});
}

sub is_jury_in_contest {
    my %p = @_;
    return 1 if $is_root;
    # Optimization: if the request is about the current contest, return cached value.
    return $is_jury if defined $cid && $p{contest_id} == $cid;
    my ($j) = get_registered_contestant(fields => 'is_jury', @_);
    return $j;
}

sub all_sites_finished {
    my ($contest_id) = @_;
    return 0 if $contest_id == $cid && $contest->{time_since_finish} <= 0;

    my ($main_time_since_finish, $all_sites) = $dbh->selectrow_array(qq~
        SELECT
            CAST(CURRENT_TIMESTAMP - finish_date AS DOUBLE PRECISION),
            CASE WHEN EXISTS (
                SELECT 1 FROM contest_sites CS
                WHERE CS.contest_id = C.id AND
                    CURRENT_TIMESTAMP < $CATS::Time::contest_site_finish_sql)
            THEN 0 ELSE 1 END
        FROM contests C WHERE C.id = ?~, undef,
        $contest_id);
   $main_time_since_finish > 0 && $all_sites;
}

sub flags_can_participate {
    my $contest_finished = all_sites_finished($cid);
    return (
        can_participate_online =>
            $uid && !$contest->{closed} && !$user->{is_participant} && !$contest_finished,
        can_participate_virtual =>
            $uid && !$contest->{closed} && (!$user->{is_participant} || $user->{is_virtual}) &&
            $contest->{time_since_start} >= 0 &&
            (!$contest->{is_official} || $contest_finished));
}

sub online {
    !$user->{is_participant} or return msg(1111, $contest->{title});

    if ($is_root) {
        $contest->register_account(account_id => $uid, is_jury => 1, is_pop => 1, is_hidden => 1);
    }
    else {
        !$contest->{closed} or return msg(1105, $contest->{title});
        $contest->{time_since_finish} <= 0 or return msg(1108, $contest->{title});
        $contest->register_account(account_id => $uid);
    }
    $dbh->commit;
    $user->{is_participant} = 1;
    msg(1110, $contest->{title});
}

sub virtual {
    !$user->{is_participant} || $user->{is_virtual}
        or return msg(1114, $contest->{title});

    !$contest->{closed}
        or return msg(1105, $contest->{title});

    $contest->{time_since_start} >= 0
        or return msg(1109);

    # In official contests, virtual participation is allowed only after the finish.
    !$contest->{is_official} || all_sites_finished($cid)
        or return msg(1122);

    my $removed_req_count = 0;
    # Repeat virtual registration removes old results.
    if ($user->{is_participant}) {
        $removed_req_count = $dbh->do(q~
            DELETE FROM reqs WHERE account_id = ? AND contest_id = ?~, undef,
            $uid, $cid);
        $dbh->do(q~
            DELETE FROM snippets WHERE account_id = ? AND contest_id = ?~, undef,
            $uid, $cid);
        $dbh->do(q~
            DELETE FROM contest_accounts WHERE account_id = ? AND contest_id = ?~, undef,
            $uid, $cid);
    }

    $contest->register_account(
        contest_id => $cid, account_id => $uid,
        is_virtual => 1, is_remote => $user->{is_remote},
        diff_time => $contest->{time_since_start});
    $dbh->commit;
    $user->{is_participant} = 1;
    $user->{is_virtual} = 1;
    $user->{diff_time} = $contest->{time_since_start};
    msg($removed_req_count > 0 ? 1113 : 1112, $contest->{title}, $removed_req_count);
}

1;
