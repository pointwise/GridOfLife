#############################################################################
#
# (C) 2021 Cadence Design Systems, Inc. All rights reserved worldwide.
#
# This script is not supported by Cadence Design Systems, Inc.
# It is provided freely for demonstration purposes only.
# SEE THE WARRANTY DISCLAIMER AT THE BOTTOM OF THIS FILE.
#
#############################################################################

# Grid of Life plays Conway's Game of Life on a structured surface grid.

package require PWI_Glyph 2.4

# Make sure there's at least one structured domain.
set numStrDoms [pw::Grid getCount -type pw::DomainStructured]
if { $numStrDoms < 1 } {
   puts "There are no structured domains."
   exit
}

if { $numStrDoms > 1 } {
   # Have the user select one structured domain.
   set sm [pw::Display createSelectionMask -requireDomain { Structured }]
   set desc "Select one structured domain."
   set picked [pw::Display selectEntities -description $desc \
                                          -selectionmask $sm \
                                          -single results]
   set Dom $results(Domains)
} else {
   # Use the only structured domain.
   set Dom [lindex [pw::Grid getAll -type pw::DomainStructured] 0]
}

# Get the domain's dimensions.
set Dim [$Dom getDimensions]
set Imax [lindex $Dim 0]
set Jmax [lindex $Dim 1]
# Set the dimensions of the cell array.
set cImax [expr $Imax - 1]
set cJmax [expr $Jmax - 1]
set nCells [expr $cImax * $cJmax]

# Create a Coon's patch database surface for every grid cell.
# These DB surfaces are what the game actually uses.
# Nomenclature is...
#
#  P4 (i  ,j+1) ---C3--- P3 (i+1,j+1)
#  |                     |
#  |                     |
#  C4                    C2
#  |                     |
#  |                     |
#  P1 (i  ,j  ) ---C1--- P2 (i+1,j  )

set listCells [list]
for { set j 1 } { $j < $Jmax } { incr j } {
   for { set i 1 } { $i < $Imax } { incr i } {

      # Get the coordinates of the cell's four corners.
      set k "$i $j"
      set P1 [$Dom getXYZ $k]
      set k "[expr $i +1] $j"
      set P2 [$Dom getXYZ $k]
      set k "[expr $i +1] [expr $j +1]"
      set P3 [$Dom getXYZ $k]
      set k "$i [expr $j +1]"
      set P4 [$Dom getXYZ $k]

      # Create 4 db lines around the cell.
      set seg [pw::SegmentSpline create]
      $seg addPoint $P1
      $seg addPoint $P2
      set C1 [pw::Curve create]
      $C1 addSegment $seg

      set seg [pw::SegmentSpline create]
      $seg addPoint $P2
      $seg addPoint $P3
      set C2 [pw::Curve create]
      $C2 addSegment $seg

      set seg [pw::SegmentSpline create]
      $seg addPoint $P3
      $seg addPoint $P4
      set C3 [pw::Curve create]
      $C3 addSegment $seg

      set seg [pw::SegmentSpline create]
      $seg addPoint $P4
      $seg addPoint $P1
      set C4 [pw::Curve create]
      $C4 addSegment $seg

      # Create a Coons patch from those 4 lines.
      set Cell($i,$j) [pw::Surface createFromCurves [list $C1 $C2 $C3 $C4]]
      lappend listCells $Cell($i,$j)

      # Delete the 4 lines.
      pw::Entity delete [list $C1 $C2 $C3 $C4]

      # Initialize the cell to dead.
      set Live($i,$j) 0

   }
   set pctg [expr 100.0 * ($j * $cImax) / $nCells]
   puts [format "%s %.1f %s" "Initializing" $pctg "%"]
}

set hardcoded 1
if { $hardcoded == 1 } {

   # Hard code the live cells.
   # These are a hardcoded demo for a 42x37 grid.

   # Gosper's Glider Gun

   set Live(2,25) 1
   set Live(2,26) 1
   set Live(3,25) 1
   set Live(3,26) 1
   
   set Live(12,24) 1
   set Live(12,25) 1
   set Live(12,26) 1
   set Live(13,23) 1
   set Live(13,27) 1
   set Live(14,22) 1
   set Live(14,28) 1
   set Live(15,22) 1
   set Live(15,28) 1
   set Live(16,25) 1
   set Live(17,23) 1
   set Live(17,27) 1
   set Live(18,24) 1
   set Live(18,25) 1
   set Live(18,26) 1
   set Live(19,25) 1

   set Live(22,26) 1
   set Live(22,27) 1
   set Live(22,28) 1
   set Live(23,26) 1
   set Live(23,27) 1
   set Live(23,28) 1
   set Live(24,25) 1
   set Live(24,29) 1
   set Live(26,24) 1
   set Live(26,25) 1
   set Live(26,29) 1
   set Live(26,30) 1

   set Live(36,27) 1
   set Live(36,28) 1
   set Live(37,27) 1
   set Live(37,28) 1
   
} else {

   # Select the Coons patches representing the cells to be made live.
   set sm [pw::Display createSelectionMask -requireDatabase { Surfaces } ]
   set desc "Select the initial live cells."
   set picked [pw::Display selectEntities -description $desc \
                                          -selectionmask $sm \
                                          -pool $listCells \
                                          results]
   set Seed $results(Databases)
   set nSeeds [llength $Seed]

   # use the selected cells
   for { set j 1 } { $j < $Jmax } { incr j } {
      for { set i 1 } { $i < $Imax } { incr i } {
         for { set n 0 } { $n < $nSeeds } { incr n } {
            if { [lindex $Seed $n] == $Cell($i,$j) } {
               set Live($i,$j) 1
            }
         }
      }
   }

}

# Cycle through the rules for the generations.
set numGenerations 200
for { set n 1 } { $n < $numGenerations } { incr n } {
   if { [expr $n % 10] == 0 } {
      puts "Geneneration $n of $numGenerations"
   }

   # Shade every live cell.
   for { set j 1 } { $j < $Jmax } { incr j } {
      for { set i 1 } { $i < $Imax } { incr i } {
         if { $Live($i,$j) == 1} {
            $Cell($i,$j) setRenderAttribute FillMode Shaded
         } else {
            $Cell($i,$j) setRenderAttribute FillMode None
         }
      }
   }
   pw::Display update

   # Loop through every cell.
   for { set j 1 } { $j < $Jmax } { incr j } {
      for { set i 1 } { $i < $Imax } { incr i } {

         # Each cell has at most 8 neighbors.  Set their indices.
         # 7 6 5
         # 8 . 4
         # 1 2 3
         set u1 [expr $i - 1]
         set v1 [expr $j - 1]
         set u2       $i
         set v2 [expr $j - 1]
         set u3 [expr $i + 1]
         set v3 [expr $j - 1]
         set u4 [expr $i + 1]
         set v4       $j
         set u5 [expr $i + 1]
         set v5 [expr $j + 1]
         set u6       $i
         set v6 [expr $j + 1]
         set u7 [expr $i - 1]
         set v7 [expr $j + 1]
         set u8 [expr $i - 1]
         set v8       $j
         # Count the number of live neighbors
         set nLN($i,$j) 0
         # Corners
         if { $i == 1 && $j == 1 } {
            if { $Live($u4,$v4) == 1 } { incr nLN($i,$j) }
            if { $Live($u5,$v5) == 1 } { incr nLN($i,$j) }
            if { $Live($u6,$v6) == 1 } { incr nLN($i,$j) }
         } elseif { $i == $cImax && $j == 1 } {
            if { $Live($u6,$v6) == 1 } { incr nLN($i,$j) }
            if { $Live($u7,$v7) == 1 } { incr nLN($i,$j) }
            if { $Live($u8,$v8) == 1 } { incr nLN($i,$j) }
         } elseif { $i == $cImax && $j == $cJmax } {
            if { $Live($u1,$v1) == 1 } { incr nLN($i,$j) }
            if { $Live($u2,$v2) == 1 } { incr nLN($i,$j) }
            if { $Live($u8,$v8) == 1 } { incr nLN($i,$j) }
         } elseif { $i == 1 && $j == $cJmax } {
            if { $Live($u2,$v2) == 1 } { incr nLN($i,$j) }
            if { $Live($u3,$v3) == 1 } { incr nLN($i,$j) }
            if { $Live($u4,$v4) == 1 } { incr nLN($i,$j) }
         } elseif { $i == 1 } {
            if { $Live($u2,$v2) == 1 } { incr nLN($i,$j) }
            if { $Live($u3,$v3) == 1 } { incr nLN($i,$j) }
            if { $Live($u4,$v4) == 1 } { incr nLN($i,$j) }
            if { $Live($u5,$v5) == 1 } { incr nLN($i,$j) }
            if { $Live($u6,$v6) == 1 } { incr nLN($i,$j) }
         } elseif { $i == $cImax } {
            if { $Live($u1,$v1) == 1 } { incr nLN($i,$j) }
            if { $Live($u2,$v2) == 1 } { incr nLN($i,$j) }
            if { $Live($u6,$v6) == 1 } { incr nLN($i,$j) }
            if { $Live($u7,$v7) == 1 } { incr nLN($i,$j) }
            if { $Live($u8,$v8) == 1 } { incr nLN($i,$j) }
         } elseif { $j == 1 } {
            if { $Live($u4,$v4) == 1 } { incr nLN($i,$j) }
            if { $Live($u5,$v5) == 1 } { incr nLN($i,$j) }
            if { $Live($u6,$v6) == 1 } { incr nLN($i,$j) }
            if { $Live($u7,$v7) == 1 } { incr nLN($i,$j) }
            if { $Live($u8,$v8) == 1 } { incr nLN($i,$j) }
         } elseif { $j == $cJmax } {
            if { $Live($u1,$v1) == 1 } { incr nLN($i,$j) }
            if { $Live($u2,$v2) == 1 } { incr nLN($i,$j) }
            if { $Live($u3,$v3) == 1 } { incr nLN($i,$j) }
            if { $Live($u4,$v4) == 1 } { incr nLN($i,$j) }
            if { $Live($u8,$v8) == 1 } { incr nLN($i,$j) }
         } else {
            if { $Live($u1,$v1) == 1 } { incr nLN($i,$j) }
            if { $Live($u2,$v2) == 1 } { incr nLN($i,$j) }
            if { $Live($u3,$v3) == 1 } { incr nLN($i,$j) }
            if { $Live($u4,$v4) == 1 } { incr nLN($i,$j) }
            if { $Live($u5,$v5) == 1 } { incr nLN($i,$j) }
            if { $Live($u6,$v6) == 1 } { incr nLN($i,$j) }
            if { $Live($u7,$v7) == 1 } { incr nLN($i,$j) }
            if { $Live($u8,$v8) == 1 } { incr nLN($i,$j) }
         }
      }
   }

   # Apply the rules of Conway's Game of Life
   # Tick is the next generation, Live is the current generation.
   for { set j 1 } { $j < $Jmax } { incr j } {
      for { set i 1 } { $i < $Imax } { incr i } {
         set Tick($i,$j) $Live($i,$j)
         if { $Live($i,$j) == 1 && $nLN($i,$j) < 2 } {
            # Any live cell with fewer than 2 live neighbors dies.
            set Tick($i,$j) 0
         }
         if { $Live($i,$j) == 1 } {
            if { $nLN($i,$j) == 2 || $nLN($i,$j) == 3 } {
               # Any live cell with 2 or 3 live neighbors lives.
               set Tick($i,$j) 1
            }
         }
         if { $Live($i,$j) == 1 && $nLN($i,$j) > 3 } {
            # Any live cell with more than 3 live neighbors dies.
            set Tick($i,$j) 0
         }
         if { $Live($i,$j) == 0 && $nLN($i,$j) == 3 } {
            # Any dead cell with exactly 3 live neighbors lives.
            set Tick($i,$j) 1
         }
      }
   }

   # Tick becomes the new Live array
   for { set j 1 } { $j < $Jmax } { incr j } {
      for { set i 1 } { $i < $Imax } { incr i } {
         set Live($i,$j) $Tick($i,$j)
      }
   }
 
}

# Delete all the Coons patches
for { set j 1 } { $j < $Jmax } { incr j } {
   for { set i 1 } { $i < $Imax } { incr i } {
      pw::Entity delete $Cell($i,$j)
   }
}

#############################################################################
#
# This file is licensed under the Cadence Public License Version 1.0 (the
# "License"), a copy of which is found in the included file named "LICENSE",
# and is distributed "AS IS." TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE
# LAW, CADENCE DISCLAIMS ALL WARRANTIES AND IN NO EVENT SHALL BE LIABLE TO
# ANY PARTY FOR ANY DAMAGES ARISING OUT OF OR RELATING TO USE OF THIS FILE.
# Please see the License for the full text of applicable terms.
#
#############################################################################
