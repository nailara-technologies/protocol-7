// power : broken ring and switch stem
union {
    difference {
        torus { 0.52, 0.10 rotate <90, 0, 0> }
        box { <-0.20, 0.28, -0.25>, <0.20, 0.82, 0.25> }
    }
    box { <-0.09, 0.02, -0.14>, <0.09, 0.76, 0.14> }
    material { IconMaterial }
}
