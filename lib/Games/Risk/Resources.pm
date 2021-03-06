use 5.010;
use strict;
use warnings;

package Games::Risk::Resources;
# ABSTRACT: utility module to load bundled resources

use File::Basename qw{ basename };
use File::ShareDir qw{ dist_dir };
use File::Spec::Functions;
use FindBin qw{ $Bin };
use POE qw{ Loop::Tk };
use Path::Class;
use Readonly;
use Tk;
use Tk::JPEG;
use Tk::PNG;


use base qw{ Exporter };
our @EXPORT_OK = qw{ image map_path maps $SHAREDIR };
my (%images, %maps);

Readonly our $SHAREDIR => _find_sharedir();


#--
# SUBROUTINES

# -- public subs

#
# my $img = image( $name );
#
# return the Tk image called $name.
#
sub image {
    return $images{ $_[0] };
}


#
# my $path = map_path( $name );
#
# return the absolute path of the map $name.
#
sub map_path {
    my ($map) = @_;
    return $maps{$map};
}


#
# my @maps = maps();
#
# return the names of all the maps bundled with GR.
#
sub maps {
    my @maps = sort keys %maps;
    return @maps;
}


# -- private subs

#
# _find_maps( $dirname );
#
# find all maps bundled with the package.
#
sub _find_maps {
    my ($dirname) = @_;

    my $glob = catfile($dirname, 'maps', '*.map');
    %maps = map { ( basename($_,qw{.map}) => $_ ) } glob $glob;
}

sub _find_sharedir {
    my $root = dir($Bin)->parent;
    return $root->subdir('share') if -f $root->file('dist.ini');
    return dir( dist_dir( 'Games-Risk' ) );
}


#
# _load_images( $dirname );
#
# load images from $dirname/images/*.png
#
sub _load_images {
    my ($dirname) = @_;

    my $glob = catfile($dirname, 'images', '*.png');
    foreach my $path ( glob $glob ) {
        my $name = basename( $path, qw{.png} );
        $images{$name} = $poe_main_window->Photo(-file => $path);
    }
}


#
# _load_tk_icons( $dirname );
#
# load tk icons from $dirname/images/tk_icons.
# code & artwork taken from Tk::ToolBar
#
sub _load_tk_icons {
    my ($dirname) = @_;

    my $path = catfile($dirname, 'images', 'tk_icons');
    open my $fh, '<', $path or die "can't open '$path': $!";
    while (<$fh>) {
        chomp;
        last if /^#/; # skip rest of file
        my ($name, $data) = (split /:/)[0, 4];
        $images{$name} = $poe_main_window->Photo(-data => $data);
    }
    close $fh;
}


#--
# INITIALIZATION

BEGIN {
    my $dirname = dist_dir('Games-Risk');
    _load_tk_icons($dirname);
    _load_images($dirname);
    _find_maps($dirname);
}


1;

__END__


=head1 SYNOPSIS

    use Games::Risk::Resources qw{ image };
    my $image = image('actexit16');



=head1 DESCRIPTION

This module is a focal point to access all resources bundled with
C<Games::Risk>. Indeed, instead of each package to reinvent its loading
mechanism, this package provides handy functions to do that.

Moreover, by loading all the images at the same location, it will ensure
that they are not loaded twice, cutting memory eating.



=head1 SUBROUTINES

C<Games::Risk::Resources> deals with various resources bundled within
the distribution. It doesn't export anything by default, but the
following subs are available for your import pleasure.


=head2 Image resources

The images used for the GUI are bundled and loaded as C<Tk::Photo> of
C<$poe_main_window>.


=over 4

=item my $img = image( $name )

Return the Tk image called C<$name>. It can be directly used within Tk.


=back



=head2 Map resources

Map resources are playable maps, to allow more playing fun.


=over 4

=item my $path = map_path( $name )

Return the absolute path of the map C<$name>.


=item my @names = maps( )

Return the names of all the maps bundled with C<Games::Risk>.


=back



=head1 SEE ALSO

L<Games::Risk>.

