#
# This file is part of Games::Risk.
# Copyright (c) 2008 Jerome Quelin, all rights reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU GPLv3+.
#
#

package Games::Risk::AI;

use 5.010;
use strict;
use warnings;

use Carp;
use List::Util qw{ shuffle };
use POE;
use Readonly;
use aliased 'POE::Kernel' => 'K';

use base qw{ Class::Accessor::Fast };
__PACKAGE__->mk_accessors( qw{ player } );

my @NAMES = shuffle (
    'Napoleon',             # france,   1769  - 1821
    'Staline',              # russia,   1878  - 1953
    'Alexander the Great',  # greece,   356BC - 323BC
    'Julius Caesar',        # rome,     100BC - 44BC
    'Attila',               # hun,      406   - 453
    'Genghis Kahn',         # mongolia, 1162  - 1227
    'Charlemagne',          # france,   747   - 814
    'Saladin',              # iraq,     1137  - 1193
);
my $Id_name = 0;


#--
# CLASS METHODS

# -- constructor

#
# my $ai = Games::Risk::AI::$AItype->new( \%params );
#
# Note that you should not instantiate a Games::Risk::AI object directly:
# instantiate an AI subclass.
#
# Create a new AI of type $AItype. All subclasses accept the following
# parameters:
#  - player: the Game::Risk::Player associated to the AI. (mandatory)
#
# Note that the AI will automatically get a name, and update the player object.
#
sub new {
    my ($pkg, $args) = @_;

    # assign a new color
    my $nbnames = scalar(@NAMES);
    croak "can't assign more than $nbnames names" if $Id_name >= $nbnames;
    my $name = $NAMES[ $Id_name++ ];

    # create the object
    my $self = bless $args, $pkg;

    # update other object attributes
    $self->player->name( $name );

    return $self;
}



#
# my $id = Games::Risk::AI->spawn( $ai )
#
# This method will create a POE session responsible for the artificial
# intelligence $ai. It will return the poe id of the session newly created. The
# session will also react to the ai's player name (poe alias).
#
sub spawn {
    my ($type, $ai) = @_;

    my $session = POE::Session->create(
        heap          => $ai,
        inline_states => {
            # private events - session management
            _start         => \&_onpriv_start,
            _stop          => sub { warn "AI shutdown\n" },
            # public events
            attack                   => \&_onpub_attack,
            attack_move              => \&_onpub_attack_move,
            move_armies              => \&_onpub_move_armies,
            place_armies     => \&_onpub_place_armies,
            place_armies_initial     => \&_onpub_place_armies_initial,
        },
    );
    return $session->ID;

}


#--
# METHODS

# -- public methods

#
# my $str = $ai->description;
#
# Format the subclass description.
#
sub description {
    my ($self) = @_;
    my $descr = $self->_description;
    $descr =~ s/[\n\s]+\z//;
    $descr =~ s/\A\n+//;
    return $descr;
}


#
# my @where = $ai->move_armies;
#
# See pod in Games::Risk::AI for information on the goal of this method.
#
# This implementation will not move any armies at all.
#
sub move_armies {
    my ($self) = @_;
    return;
}



#--
# EVENTS HANDLERS

# -- public events

#
# event: attack();
#
# request the ai to attack a country, or to end its attack turn.
#
sub _onpub_attack {
    my $ai = $_[HEAP];
    my ($action, @params) = $ai->attack;
    K->post('risk', $action, @params);
}


#
# event: attack_move($src, $dst, $min);
#
# request the ai to move some armies from $src to $dst (minimum $min)
# after a succesful attack.
#
sub _onpub_attack_move {
    my ($ai, $src, $dst, $min) = @_[HEAP, ARG0..$#_];
    my $nb = $ai->attack_move($src, $dst, $min);
    K->post('risk', 'attack_move', $src, $dst, $nb);
}


#
# event: move_armies();
#
# request the ai to move armies between adjacent countries, or to end
# its move turn.
#
sub _onpub_move_armies {
    my $ai = $_[HEAP];

    foreach my $move ( $ai->move_armies ) {
        my ($src, $dst, $nb) = @$move;
        K->post('risk', 'move_armies', $src, $dst, $nb);
    }

    K->post('risk', 'armies_moved');
}


#
# event: place_armies($nb, $continent);
#
# request the ai to place $nb armies, possibly within $continent (if defined).
#
sub _onpub_place_armies {
    my ($ai, $nb, $continent) = @_[HEAP, ARG0, ARG1];

    foreach my $where ( $ai->place_armies($nb, $continent) ) {
        my ($country, $nb) = @$where;
        K->post('risk', 'armies_placed', $country, $nb);
    }
}


#
# event: place_armies_initial();
#
# request the ai to place 1 army on a country.
#
sub _onpub_place_armies_initial {
    my $ai = $_[HEAP];

    my ($where) = $ai->place_armies(1);
    my ($country, $nb) = @$where;
    K->post('risk', 'initial_armies_placed', $country, $nb);
}


# -- private events - session management

#
# event: _start( \%params )
#
# Called when the poe session gets initialized. Receive a reference
# to %params, same as spawn() received.
#
sub _onpriv_start {
    my $ai = $_[HEAP];
    K->alias_set( $ai->player->name );
    K->post('risk', 'player_created', $ai->player);
}


1;

__END__



=head1 NAME

Games::Risk::AI - base class for all ais



=head1 SYNOPSIS

    [don't use this class directly]



=head1 DESCRIPTION

This module is the base class for all artificial intelligence. It implements
also a POE session representing an AI player. This POE session will retain the
C<Games::Risk::AI::*> object as heap.



=head1 METHODS

=head2 Constructor


=over 4

=item * my $ai = Games::Risk::AI::$AItype->new( \%params )

Create a new AI of type C<$AItype>. Note that you should not instantiate a
C<Games::Risk::AI> object directly: instantiate an AI subclass instead. All
subclasses accept the following parameters:


=over 4

=item * player: the C<Game::Risk::Player> associated to the AI. (mandatory)

=back


Note that the AI will automatically get a name, and update the player object.


=item * my $id = Games::Risk::AI->spawn( $ai )

This method will create a POE session responsible for the artificial
intelligence C<$ai>. It will return the poe id of the session newly created.
The session will also react to the ai's player name (poe alias).


=back


=head2 Object methods

An AI object will typically implements the following methods:


=over 4

=item * my ($action, [$from, $country]) = $ai->attack()

Return the attack plan, which can be either C<attack> or C<attack_end> to stop
this step of the ai's turn. If C<attack> is returned, then it should also
supply C<$from> and C<$country> parameters to know the attack parameters.


=item * my $nb = $ai->attack_move($src, $dst, $min)

Return the number of armies to move from C<$src> to C<$dst> after a
successful attack (minimum C<$nb> to match the number of attack dices).


=item * my $str = $ai->description()

Return a short description of the ai and how it works.


=item * my $str = $ai->difficulty()

Return a difficulty level for the ai.


=item * my @moves = $ai->move_armies()

Return a list of C<[ $src, $dst, $nb ]> tuples (two
C<Games::Risk::Map::Country> and an integer), each defining a move of
C<$nb> armies from $dst to C<$src>.


=item * my @where = $ai->place_armies($nb, [$continent])

Return a list of C<[ $country, $nb ]> tuples (a C<Games::Risk::Map::Country>
and an integer) defining where to place C<$nb> armies. If C<$continent> (a
C<Games::Risk::Map::Continent>) is defined, all the returned C<$countries>
should be within this continent.


=back

Note that some of those methods may be inherited from the base class, when it
provide sane defaults.


=begin quiet_pod_coverage

=item * K

=end quiet_pod_coverage



=head1 SEE ALSO

L<Games::Risk>.



=head1 AUTHOR

Jerome Quelin, C<< <jquelin at cpan.org> >>



=head1 COPYRIGHT & LICENSE

Copyright (c) 2008 Jerome Quelin, all rights reserved.

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU GPLv3+.

=cut

