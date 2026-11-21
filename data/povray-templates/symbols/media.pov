// media : play triangle in a ring
union {
    torus { 0.70, 0.07 rotate <90, 0, 0> }
    prism { linear_spline -0.14, 0.14, 4,
            <-0.34, -0.48>, <0.52, 0>, <-0.34, 0.48>, <-0.34, -0.48>
            rotate <90, 0, 0> }
    material { IconMaterial }
}
