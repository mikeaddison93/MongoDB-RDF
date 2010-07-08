package MongoDB::RDF::Graph;
use strict;
use warnings;

use MongoDB;

use MongoDB::RDF::Util qw( canonical_uri fencode fdecode );
use MongoDB::RDF::Namespace qw( resolve );

=head2 new

=cut

sub new {
    my $class = shift;
    my %args = @_;
    my $self = bless {}, $class;
    # TODO valiation
    for (qw(name mrdf)) {
        die "$_ required" unless $args{$_};    
        $self->{$_} = $args{$_};
    }
    # TODO maintain a global cache of the ensured indexes
    # the cost of ensure_index may not be negligable 
    $self->collection->ensure_index({ _subject => 1 }, { unique => 1 });
    return $self;
}

=head2 name

=cut

sub name { $_[0]->{name} }

sub _mrdf { $_[0]->{mrdf} }

=head2 collection

Gives you direct access to the MongoDB::Collection hidden behind the graph.

=cut

sub collection {
    my $self = shift;
    my $name = $self->name;
    return $self->_mrdf->database->$name();
}

=head2 load

Loads a resource from the graph.

=cut

sub load {
    my $self = shift;
    my $uri = shift or die 'uri required';
    $uri = canonical_uri($uri);
    my $c = $self->collection;
    my $doc = $c->find_one(
        { _subject => $uri },
    );
    return unless $doc;
    return MongoDB::RDF::Resource->new_from_document($doc);
}

=head2 save

Saves a resource in the graph.

=cut

sub save {
    my $self = shift;
    my ($resource) = @_;
    my $c = $self->collection;
    return $c->update(
        { _subject => $resource->subject },
        $resource->document,
        { upsert => 1 }
    );
}

=head2 remove

removes a resource from the graph.

=cut

sub remove {
    my $self = shift;
    my ($resource) = @_;
    my $c = $self->collection;
    return $c->remove({ _subject => $resource->subject });
}

=head2 find

=cut

sub find {
    my $self = shift;
    my ($query) = @_;
    for my $key (keys %$query) {
        my $value = delete $query->{$key};
        $key = fencode(resolve($key)).'.value';
        # TODO $elemMatch or dotnotation ?
        $query->{$key} = $value;
    }
    my $c = $self->collection;
    my $cursor = $c->find($query);
    return MongoDB::RDF::Cursor->new($cursor);
}

=head2 ensure_index

=cut

sub ensure_index {
    my $self = shift;
    my ($fields, $opts) = @_;
    for my $key (keys %$fields) {
        my $value = delete $fields->{$key};
        $key = fencode(resolve($key)).'.value';
        $fields->{$key} = $value;
    }
    my $c = $self->collection;
    $c->ensure_index($fields, $opts);
}

package MongoDB::RDF::Cursor;
use strict;
use warnings;

sub new {
    my $class = shift;
    my ($cursor) = @_;
    return bless { cursor => $cursor }, $class;
}

=head2 cursor

Returns the underlying MongoDB::Cursor

=cut

sub cursor { $_[0]->{cursor} }

=head2 next

=cut

sub next {
    my $self = shift;    
    my $doc = $self->cursor->next;
    return unless $doc;
    return MongoDB::RDF::Resource->new_from_document($doc);
}

=head2 count

=cut

sub count {
    my $self = shift;    
    return $self->cursor->count(@_);
}

1;