// terminal : window outline and command prompt
union {
    difference {
        box { <-0.78, -0.62, -0.14>, <0.78, 0.62, 0.14> }
        box { <-0.66, -0.50, -0.20>, <0.66, 0.50, 0.20> }
    }
    cylinder { <-0.42,  0.18, 0>, <-0.18,  0.00, 0>, 0.07 }
    cylinder { <-0.18,  0.00, 0>, <-0.42, -0.18, 0>, 0.07 }
    cylinder { <-0.08, -0.22, 0>, < 0.38, -0.22, 0>, 0.07 }
    material { IconMaterial }
}
