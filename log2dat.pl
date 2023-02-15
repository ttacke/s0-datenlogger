use strict;
use warnings;
BEGIN {
	eval {
		require DateTime;
	};
	if ($@) {
		die "Fehler: DateTime-Modul nicht gefunden. Installieren z.B. via 'sudo apt-get install libdatetime-perl'";
	}
}
# TODO werte vorgegeben zum entwickeln
my $filename = $ARGV[0] || 's0-20200904856-57330,94-202009210820-57442,56-111,62kwh.log';
my $datum = $ARGV[1] || '2020-09-04T08:56';
my $u_pro_kwh = $ARGV[2] || '75';
my $date_regex = qr/^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})$/;
if (!$filename || !-f ($filename) || $datum !~ $date_regex || $u_pro_kwh !~ m/^[1-9][0-9]+$/) {
	die "Aufruf via: $0 [LOGFILE] [DATUM:YYYY-MM-DDTHH:MM] [UMDREHUNGEN_PRO_KWH]"
		. "\nBsp: $0 time.log 2020-07-31T17:30 75 >> verbrauch.dat"
		. "\nHinweis: U/kWh steht auf dem Zähler\n";
}

my $startzeitpunkt = undef;
$datum =~ $date_regex;
$startzeitpunkt = DateTime->new(
	year      => $1,
	month     => $2,
	day       => $3,
	hour      => $4,
	minute    => $5,
	second    => 0,
	time_zone => 'Europe/Berlin',
);

my $liste = _lese_liste($filename);
my $triggerwerte = _ermittle_triggerwert($liste);
warn "High(silber) = $triggerwerte->{'high'}\n";

my $gefundene_kwh = [];
#foreach my $low (@{$triggerwerte->{'low_liste'}}) {
#	my $zeitpunkte = _finde_werteuebergaenge($triggerwerte->{'high'}, $low, $liste, $startzeitpunkt->epoch());
#	my $kw_h = sprintf("%.2f", scalar(@$zeitpunkte) / $u_pro_kwh);
#	if (grep {$_->{kwh} == $kw_h} @$gefundene_kwh) {
#		next;
#	}
#
#	push(@$gefundene_kwh, { low => $low, kwh => $kw_h, zeitpunkte => $zeitpunkte });
#}
# TODO werteuebergang finden
my $zeitpunkte = _finde_werteuebergaenge_dynamisch($liste, $startzeitpunkt->epoch());
# my $kw_h = sprintf("%.2f", scalar(@$zeitpunkte) / $u_pro_kwh);
# push(@$gefundene_kwh, { low => $low, kwh => $kw_h, zeitpunkte => $zeitpunkte });
die('ENDE');
# TODO Ende

if (!scalar(@$gefundene_kwh)) {
	die "Keine zwei Peak-Werte gefunden. Sind da die richtigen Daten drin?";
}
if (scalar(@$gefundene_kwh) > 1) {
	while (1) {
		my $i = 0;
		warn "Mehrere Möglichkeiten gefunden, bitte wählen (Zahl + ENTER):\n";
		foreach my $e (@$gefundene_kwh) {
			warn sprintf("%s) %s kw/h bei Low = %s gefunden \n", ++$i, $e->{'kwh'}, $e->{'low'});
		}
		my $auswahl = <STDIN>;
		chomp($auswahl);
		if ($auswahl =~ m/^\d+$/ && $auswahl <= scalar(@$gefundene_kwh) && $auswahl > 0) {
			$gefundene_kwh = [ $gefundene_kwh->[$auswahl - 1] ];
			last;
		}
	}
}

warn sprintf("Low(rot) = %s -> ergibt %s kw/h\n", $gefundene_kwh->[0]->{'low'}, $gefundene_kwh->[0]->{'kwh'});

_melde_moegliche_ferraris_zaehlstopps($gefundene_kwh->[0]->{'zeitpunkte'});

foreach my $t (@{_nur_1_0_uebergaenge($gefundene_kwh->[0]->{'zeitpunkte'})}) {
	print "$t\n";
}
exit(0);

# \ARRAY
sub _melde_moegliche_ferraris_zaehlstopps {
	my ($liste) = @_;
	foreach my $e (@$liste) {
		my $laufzeit = $e->{'end'} - $e->{'start'};
		# if($laufzeit > 60) {
		# 	warn "$laufzeit\n";
		# }
	}

	return []
}
# \ARRAY
sub _nur_1_0_uebergaenge {
	my ($liste) = @_;

	my $l = [];
	foreach my $e (@$liste) {
		push(@$l, $e->{'start'});
	}
	return $l;
}
# \ARRAY
sub _finde_werteuebergaenge_dynamisch {
	my ($liste, $start_timestamp) = @_;

	# tiefsten v-wert der letzten 10 Sekunden?
	# Höchsten wert der letzten 10 Sekunden
	# liegt der wert im unteren drittel = Low
	# im oberen Drittel = High
	# Wenn übergang von low->high = Melden in Liste
	foreach my $e (@$liste) {
		my $aktueller_zustand = 0;
		next if(!$e->{'v'});

		use Data::Dumper;
		die Dumper($e);
		# my $rot_durchlauf = {};
		# $rot_durchlauf->{'start'} = $start_timestamp + sprintf("%.0f", $t / 1000);
		# $rot_durchlauf->{'end'} = $start_timestamp + sprintf("%.0f", $t / 1000);
		# push(@$result, $rot_durchlauf);
	}
	exit(1);
}
# \ARRAY
sub _finde_werteuebergaenge {
	my ($high, $low, $liste, $start_timestamp) = @_;

	my $triggerbereich = ($high - $low) / 3;
	my $vorheriger_zustand = 0;
	my $result = [];
	my $rot_durchlauf = {
		start => 0,
		end => 0,
	};
	foreach my $e (@$liste) {
		my $aktueller_zustand = 0;
		next if(!$e->{'v'});

		if ($e->{'v'} > ($high - $triggerbereich)) {
			$aktueller_zustand = 1;
		}
		elsif ($e->{'v'} < ($low + $triggerbereich)) {
			# DoNothing = Low
		}
		else {
			next; # Ungültiges ignorieren
		}
		# Übergang von 1->0 (silber->rot) finden
		if ($aktueller_zustand == 0 && $vorheriger_zustand == 1) {
			$rot_durchlauf = {
				start => 0,
				end => 0,
			};
			my $t = $e->{'t'}; # milliseconds
			$rot_durchlauf->{'start'} = $start_timestamp + sprintf("%.0f", $t / 1000);
		# Übergang 0->1 (rot->silber) finden (= 4% nach 1->0)
		} elsif ($aktueller_zustand == 1 && $vorheriger_zustand == 0) {
			my $t = $e->{'t'}; # milliseconds
			$rot_durchlauf->{'end'} = $start_timestamp + sprintf("%.0f", $t / 1000);
			if($rot_durchlauf->{'start'}) {
				push(@$result, $rot_durchlauf);
			} else {
				warn "Hinweis: Rot-Bereich ignoriert, weil kein Start auffindbar (ein paar darf das geben; viele deuten auf einen Fehler hin)\n";
			}
			$rot_durchlauf = {
				start => 0,
				end => 0,
			};
		}
		$vorheriger_zustand = $aktueller_zustand;
	}
	return $result;
}
# \HASH
sub _ermittle_triggerwert {
	my ($liste) = @_;

	my $wertebereiche = {};
	foreach my $e (@$liste) {
		$wertebereiche->{$e->{'v'}} ||= 0;
		$wertebereiche->{$e->{'v'}}++;
	}

	my $peak_werte = _finde_peaks($wertebereiche);
	my $wert_fuer_silberscheibe = _finde_max_peak_wert($wertebereiche, $peak_werte);

	my $low_liste = [ grep {$_ < $wert_fuer_silberscheibe} @$peak_werte ];
	# TODO
	# my $wert_fuer_silberscheibe = 100;
	# TODO try&error
	# my $low_liste = [];
	# for my $i (10..($wert_fuer_silberscheibe-3)) {
	# 	push(@$low_liste, $i);
	# }
	return {
		high      => $wert_fuer_silberscheibe,
		low_liste => $low_liste,
	};
}
sub _finde_max_peak_wert {
	my ($wertebereiche, $peak_werte) = @_;

	my $max_peak_anzahl = 0;
	my $max_peak_wert = 0;
	foreach my $peak_wert (@$peak_werte) {
		if ($max_peak_anzahl < $wertebereiche->{$peak_wert}) {
			$max_peak_wert = $peak_wert;
			$max_peak_anzahl = $wertebereiche->{$peak_wert}
		}
	}
	warn $max_peak_wert;
	return $max_peak_wert;
}

# \ARRAY
sub _finde_peaks {
	my ($wertebereiche) = @_;

	my $vorvoriger_wert = 0;
	my $voriger_wert = 0;
	my $peak_werte = [];
	foreach my $aktueller_wert (sort {$a <=> $b} keys(%$wertebereiche)) {
		my $aktuelle_anzahl = $wertebereiche->{$aktueller_wert};
		# TODO warn "$aktueller_wert: $aktuelle_anzahl\n";
		my $vorige_anzahl = $wertebereiche->{$voriger_wert} || 0;
		my $vorvorige_anzahl = $wertebereiche->{$vorvoriger_wert} || 0;
		if (
			$vorvorige_anzahl < $vorige_anzahl
				&&
				$vorige_anzahl > $aktuelle_anzahl
		) {
			push(@$peak_werte, $voriger_wert);
		}
		$vorvoriger_wert = $voriger_wert;
		$voriger_wert = $aktueller_wert;
	}
	# TODO use Data::Dumper;
	# TODO warn Dumper($peak_werte);
	return $peak_werte;
}
# \ARRAY
sub _lese_liste {
	my ($filename) = @_;

	open(my $fh, '<', $filename) or die $!;
	my $start_line = 0;
	my $liste = [];
	my $last_time = 0;
	my $time_offset = 0;
	while (my $line = <$fh>) {
		if ($line =~ /^time:/) {
			if (!$start_line) {
				$start_line = 1;
				next;
			}
			$time_offset = $last_time;
			next;
		}
		my ($time, $val) = split(/[;\n\r]/, $line);
		$time += $time_offset;
		$last_time = $time;
		push(@$liste, { t => $time, v => $val });
	}
	close($fh) or die $!;
	return $liste;
}
