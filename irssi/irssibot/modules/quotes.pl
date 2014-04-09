#!/usr/bin/perl -w
# CMDS aq dq iq
# CMDS lq l3q lq3
# CMDS rq r3q rq3
# CMDS quote-who quote-when
# CMDS q quote

return if (not perms("user"));

my $msg = $$irc_event{msg};
return if $msg !~ $$state{bot_triggerre};
$msg =~ s#$$state{bot_triggerre}##;

if ($msg =~ /^aq\s*(.+)/) {
    my $quote = $1;
    $$state{dbh}->do(
        "INSERT INTO ib_quotes (users_id, quote, channel, insert_time)
            VALUES (?, ?, ?, NOW())",
        undef,
        $$state{user_info}{id}, $quote, $$irc_event{channel}
    );

    return reply("that quote is duplicate.") if ($DBI::errstr =~ m#duplicate#i);

    my $quote_id = $$state{dbh}->{mysql_insertid};
    return say("Quote $quote_id added.");


} elsif ($msg =~ /^dq\s*(\d+)/) {
    my $quote_id = $1;
    my $quote_info = $$state{dbh}->selectrow_hashref(
        "SELECT * FROM ib_quotes WHERE id = ? AND channel = ?",
        undef,
        $quote_id, $$irc_event{channel}
    );

    return reply("you lack permission.") if (not perms("admin", "quotes"));

    if (defined $$quote_info{quote}) {
        $$state{dbh}->do("DELETE FROM ib_quotes WHERE id = ?", undef, $quote_id);
        return say("Quote $quote_id deleted.");
    } else {
        return reply("no quote with id $quote_id found.");
    }


} elsif ($msg =~ /^iq\s*(\d+)/) {
    my $quote_id = $1;
    my $quote_info = $$state{dbh}->selectrow_hashref(
        "SELECT * FROM ib_quotes WHERE id = ? AND channel = ?",
        undef,
        $quote_id, $$irc_event{channel}
    );

    if (defined $$quote_info{quote}) {
        return say("#$$quote_info{id} " . ($$quote_info{quote_score}?"[$$quote_info{quote_score}] ":"") . "$$quote_info{quote}");
    } else {
        return reply("no quote with id $quote_id found.");
    }


} elsif ($msg =~ /^(q|quote|rq|rq3|r3q)\s*$/) {
    my $count = 1; $count = 3 if $msg =~ /3/;

    my @quote_ids = @{$$state{dbh}->selectcol_arrayref(
        "SELECT id FROM ib_quotes
            WHERE channel = ?
        ORDER BY insert_time ASC",
        undef,
        $$irc_event{channel}
    )};
    return reply("there's no $count quotes on $$irc_event{channel}") if (scalar(@quote_ids) < $count);

    my @rnd_ids = ();
    my $c = 0;
    while ($c++ < $count) {
        push @rnd_ids, splice(@quote_ids, int(rand(scalar(@quote_ids)-1)), 1);
    }

    foreach (@rnd_ids) {
        my $quote_info = $$state{dbh}->selectrow_hashref(
            "SELECT * FROM ib_quotes WHERE id = ? AND channel = ?",
            undef,
            $_, $$irc_event{channel}
        );

        say("#$_ " . ($$quote_info{quote_score}?"[$$quote_info{quote_score}] ":"") . "$$quote_info{quote}");
    }
    return;


} elsif ($msg =~ /^(?:lq|l3q)\s*$/) {
    my $count = 1; $count = 3 if $msg =~ /3/;

    my $sth = $$state{dbh}->prepare(
        "SELECT * FROM ib_quotes
            WHERE channel = ?
        ORDER BY insert_time DESC LIMIT 3"
    );
    $sth->execute($$irc_event{channel});
    return reply("no quotes on $$irc_event{channel}.") if not $sth->rows();

    my $counter = 1;
    while (my $row = $sth->fetchrow_hashref()) {
        say("#$$row{id} " . ($$row{quote_score}?"[$$row{quote_score}] ":"") . "$$row{quote}");
        last if ++$counter > $count;
    }

    $sth->finish();
    return;
   

} elsif ($msg =~ /^quote\s*(\d+)\s*(\+\+|\-\-)/) {
    my $quote_id = $1;
    my $direction = $2;

    if ($direction eq "++") {
        $update_sql = "quote_score = quote_score + 1";
    } elsif ($direction eq "--") {
        $update_sql = "quote_score = quote_score - 1";
    }

    my $quote_info = $$state{dbh}->selectrow_hashref(
        "SELECT * FROM ib_quotes WHERE id = ? AND channel = ?",
        undef,
        $quote_id, $$irc_event{channel}
    );
    return reply("no quote with id $quote_id.") if (not defined $$quote_info{quote});

    $$state{dbh}->do(
        "UPDATE ib_quotes SET $update_sql WHERE id = ?",
        undef,
        $quote_id
    );

    $$quote_info{quote_score}++ if ($direction eq "++");
    $$quote_info{quote_score}-- if ($direction eq "--");
    return say("Quote $quote_id quote score is now $$quote_info{quote_score}.");


} elsif ($msg =~ /^quote-(?:who|when)\s*(\d+)/) {
    my $quote_id = $1;
    my $quote_info = $$state{dbh}->selectrow_hashref(
        "SELECT * FROM ib_quotes WHERE id = ? AND channel = ?",
        undef,
        $quote_id, $$irc_event{channel}
    );

    if (defined $$quote_info{quote}) {
        my $quote_user = $$state{dbh}->selectrow_hashref(
            "SELECT * FROM ib_users WHERE id = ?",
            undef,
            $$quote_info{users_id}
        );
        return reply("quote $quote_id was added by $$quote_user{ircnick} on $$quote_info{insert_time}");
    } else {
        return reply("no quote with id $quote_id found.");
    }
 

}