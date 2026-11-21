// settings : eight-tooth gear
union {
    torus { 0.43, 0.16 rotate <90, 0, 0> }
    cylinder { <0, 0, -0.14>, <0, 0, 0.14>, 0.22 }
    #for (Tooth, 0, 315, 45)
        box { <0.52, -0.11, -0.14>, <0.82, 0.11, 0.14>
              rotate <0, 0, Tooth> }
    #end
    material { IconMaterial }
}
