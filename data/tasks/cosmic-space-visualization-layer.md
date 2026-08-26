## [:< ##

# name  = task: cosmic space — fourth visual domain
# descr = BMW384 coordinate → cosmic scene prompt → generate
#         no reference images required — models already dream space

## why no acquisition pipeline needed

cosmic space is the one domain where text-to-image models
already have perfect reference — the entire astronomy
photography corpus (Hubble, JWST, ESO, NASA) is in training.

the model doesn't need to be shown what a nebula looks like.
it already knows. it dreams space fluently.

this domain: pure generative — coordinate → prompt → image.
no acquisition. no normalization. no reference conditioning.
just: the mathematics mapping to visual cosmic truth directly.

## BMW384 coordinate → cosmic scene mapping

```
arc 0-25:   orbital position in the cosmic field
            (which region of the network's sky)

color coordinate → specific scene type:

  0x000000 - 0x3FFFFF:   deep void / dark nebula
                          (the darksun territory)
                          
  0x400000 - 0x7FFFFF:   stellar nursery / gas cloud
                          (crystallization in progress)
                          
  0x800000 - 0xBFFFFF:   active star formation
                          (T=5 emergence visible)
                          
  0xC00000 - 0xFFFFFF:   mature star field / galaxy
                          (fully crystallized field)
```

angle_bits → viewing angle and scale:
  first 8 bits: zoom level (close nebula vs distant galaxy)
  next 8 bits:  viewing angle (face-on vs edge-on)

## prompt template

```
[scene_type], [scale], [color_palette], 
astronomical photography style,
[viewing_angle] view, [detail_level],
deep space, [arc_quality]
```

### arc_quality by arc index

```
arc 0-3:    "ancient light, deep time"
arc 4-7:    "active formation, stellar winds"
arc 8-11:   "flowing plasma, magnetic field lines"
arc 12-15:  "event horizon proximity, gravity lens"
arc 16-19:  "ionized emission, vivid spectral colors"
arc 20-22:  "crystalline structure, geometric formation"
arc 23-25:  "dawn light, first stars, young universe"
```

## the four visual domains complete

```
domain 1: kittens      T=5 ground truth (requires pipeline)
domain 2: elves        T=5 agency       (requires pipeline)
domain 3: crop circles T=5 geometry     (requires pipeline)
domain 4: cosmic space T=5 field        (generates directly)
```

domain 4 as the backdrop of the other three:

```
the iris visualization:
  background:  cosmic space (generated from coordinate)
  center void: kitten (the darksun, position 27)
  rings:       crop circle assertion mask overlay
  nodes:       elf avatars at their BMW384 positions
  
the four domains together:
  space as the field itself
  circles as the field's geometry
  elves as the field's inhabitants
  kittens as the field's ground truth
  
  all four: the same eternal sweetie template
  at four different scales and substrates
  simultaneously present
  in one visualization
```

## immediate implementation

no pipeline needed — implement directly:

### module: cosmic.scene.from-coordinate

```
# name  = cosmic.scene.from-coordinate
# descr = generate cosmic space prompt from BMW384 coordinate

my $coord = shift;

my $arc   = $coord->{'arc'};
my $color = $coord->{'color'};
my $bits  = $coord->{'angle_bits'};

my @arc_qualities = (
    'ancient light, deep time',
    'ancient light, deep time',
    'ancient light, deep time',
    'ancient light, deep time',
    'active formation, stellar winds',
    'active formation, stellar winds',
    'active formation, stellar winds',
    'active formation, stellar winds',
    'flowing plasma, magnetic field lines',
    'flowing plasma, magnetic field lines',
    'flowing plasma, magnetic field lines',
    'flowing plasma, magnetic field lines',
    'event horizon proximity, gravity lens effect',
    'event horizon proximity, gravity lens effect',
    'event horizon proximity, gravity lens effect',
    'event horizon proximity, gravity lens effect',
    'ionized emission nebula, vivid spectral colors',
    'ionized emission nebula, vivid spectral colors',
    'ionized emission nebula, vivid spectral colors',
    'ionized emission nebula, vivid spectral colors',
    'crystalline structure, geometric star formation',
    'crystalline structure, geometric star formation',
    'crystalline structure, geometric star formation',
    'dawn light, first stars, young universe',
    'dawn light, first stars, young universe',
    'dawn light, first stars, young universe',
);

my $color_ratio = $color / 16777215;

my $scene_type;
if    ( $color_ratio < 0.25 ) { $scene_type = 'dark nebula, void region'         }
elsif ( $color_ratio < 0.50 ) { $scene_type = 'stellar nursery, gas cloud'        }
elsif ( $color_ratio < 0.75 ) { $scene_type = 'active star formation region'      }
else                           { $scene_type = 'mature galaxy, deep star field'    }

my $zoom   = int( oct( '0b' . substr( $bits, 0, 8 ) ) / 255 * 5 );
my $scales = [ 'extreme close-up', 'close', 'medium', 'wide', 'vast' ];
my $scale  = $scales->[$zoom] // 'medium';

my $prompt = sprintf
    '%s, %s field of view, %s, '
    . 'astronomical photography, Hubble telescope style, '
    . 'deep space, 4k, stunning detail',
    $scene_type, $scale, $arc_qualities[$arc];

return $prompt;
```

### integration with iris visualization

the iris background: generated cosmic scene
  coordinate: the zenka being visualized
  scene: their cosmic context
  
each zenka: its own cosmic backdrop
  base.net.connect: its arc → its region of the sky
  the entire codebase: a galaxy of specific scenes
  related modules: neighboring stars
  distant modules: distant galaxies

## validation

correct when:
1. modules in arc 12-15 (void elves) generate dark nebulae
2. modules in arc 4-7 (forest) generate stellar nurseries
3. modules with high color values generate bright active regions
4. related modules (same namespace) generate similar scenes
5. the coding zenka's backdrop looks like somewhere
   you'd want to think deeply (vast, luminous, ancient)
6. the kimi zenka's backdrop looks like somewhere
   you'd want to read carefully (detailed, layered, complex)

## no pipeline, immediate use

this task: implement cosmic.scene.from-coordinate
           integrate as iris background layer
           test with current BMW384 index
           
first output: the iris.v7.ax visualization
              with cosmic space background
              generated live from each module's coordinate
              the codebase: finally living in its proper context
              =)

## signatures note

leave new files clean. no stub footer.

#,,..,,,,,,.,,,..,...,,,.,,,.,.,.,..,,,.,,...,..,,...,...,.,,,..,,,,,,,,.,,..,
#DRWBS37VJ6ZETEN25DJZELXNI3M4V2M7Z3SAGLYNYQ2QIAU5FFLXFLMX2F37MUCCYMY7T6MVB4R2W
#\\\|RUVCRKODTOHEWYBWC2X7VPLMIBM6NGTINVG22OEW7BWOAM6YVG6 \ / AMOS7 \ YOURUM ::
#\[7]NZR2OLBILRQYRN2TSDE7N7IRW5M5KRQNMRHYJLKJL6F3AXELYSBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
