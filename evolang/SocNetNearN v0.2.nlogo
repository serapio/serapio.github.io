;******************************;
;  Setup
;******************************;
;; The setup just creates the network of speakers
;; and sets up some globals

breed [ exemplars exemplar ]
exemplars-own [ 
  meaning      ;; an integer index of the "meaning" category
  owner        ;; the person who remembers it
  speaker      ;; the person who said it
]

breed [ people person ]
people-own [ 
  exemplar-set     ;; the set of exemplars that the person remembers
  guesses-history  ;; success indicator for the past 100 guesses
]
  
globals [ 
  lexicon      ;; the list of possible meaning categories
  showing      ;; which person's exemplar space is showing now
]



to setup
  clear-all
  set-default-shape people "person"
  make-network
  set showing "net"
  
  set lexicon [
     ;; currently the lexicon has no structure, 
     ;; but we could make semantic domains relevant
    "turtle"
    "fish"
    "cow"
    "butterfly"
    "squirrel"
    "rabbit"
    "ant"
    "spider"
;    "die 1"
;    "die 2"
;    "die 3"
;    "die 4"
;    "die 5"
;    "die 6"
;    "plant"
;    "flower"
;    "tree"
;    "leaf"
  ]

end

to reset
  ask exemplars [ die ]
end


;******************************;
;  Making the network
;******************************;
;;; This code is mostly directly from the "Language Change" model
;;; in the models library, just with some changes to allow
;;; sliders for nets that are more dense and/or less biased toward
;;; preferential-attachment

to make-network
  ;; make a bunch of isolated people
  create-people num-people [
    ;; start in random position near edge of world
    rt random-float 360
    fd max-pxcor
    set size 2
    set label who
    set color 15 + 30 * who
    set exemplar-set turtle-set [ ]
    set guesses-history (list 0)
  ]  
  
  ;; Then connect them up into a network:
  
  ;; (1) make the initial network of two nodes and an edge
  let partner nobody
  let partner2 nobody
  let first-node one-of people
  let second-node one-of people with [ self != first-node ]
  ask first-node [ create-link-with second-node [ set color white ] ] ; make the first edge
  
  ;; for each person, connect it to one or two other people
  ask people [
    let new-node self
    set partner find-partner new-node
    set partner2 find-partner new-node
    ask new-node [ create-link-with partner [ set color white ] ]
    if 1 + random-float 1 < links-per-person [
       ask new-node [ create-link-with partner2 [ set color white ] ]
    ]
    layout
  ]
end


to-report find-partner [for-node]
  ;; There are two strategies for choosing a partner:
  ;; (1) pick with uniform probability from all other people
  ;; (2) pick with people with a probability proportional to the number of links they have
  ;; This code lets you interpolate between these strategies, using a raffle ticket system
  let pick random-float ((100 - pref-attach) * (-1 + count people)
                        + (pref-attach) * sum [count link-neighbors] of (people with [self != for-node])
                        )
  let partner nobody
  ;; step through the line of people, counting out their tickets until you get to the winner
  ask people with [ self != for-node ] [
    ;; if there's no winner yet...
    if partner = nobody [
      ifelse ((100 - pref-attach) + pref-attach * count link-neighbors) > pick [
        set partner self
      ][
        set pick pick - ((100 - pref-attach) + pref-attach * count link-neighbors)
      ]
    ]
  ]
  report partner
end

to layout
  layout-spring (people with [any? link-neighbors]) links 0.05 6 1
  display  ;; for smooth animation
end



;******************************;
;  Let the people talk
;******************************;
;; There are two modes of talking:
;;  - In the hear-neighbors=True mode, each person selects an interlocutor, and they
;;    try to communicate a message. Depending on their success, they both might store
;;    an exemplar of that communication.
;;  - In the hear-neighbors=False mode, each person speaks a random message, storing
;;    an exemplar, and then each person hears a random message, also storing an exemplar

to go
  ;; speak ;; have each person make their own exemplars
  ;; listen ;; have each person integrate a foreign exemplar
  ifelse hear-neighbors [
    speak-and-listen ;; each person listens to another person, and they each make exemplars
  ]
  [
    speak ;; each person speaks an arbitrary meaning
    listen ;; each person hears an arbitrary form and categorizes it
  ]
  
  ask exemplars ;; kill some exemplars off, indiscriminately
  [
    if random-float 1 < forget-rate [ die ]
  ]
  
  do-plots
end

to speak-and-listen
  ask people [ ;; ask each person to be a hearer
   
    let ex-src get-source-exemplar self ;; find a speaker to listen to
    
    ask ex-src [
      let talker owner
      let hearer myself
      
      hatch-exemplars 1 [
        set speaker talker
        set label [who] of speaker
        set color [color] of speaker
        ;; meaning is copied from mother exemplar
        set owner hearer
        set hidden? not (showing = [who] of owner)
        
        ;; add production noise
        set xcor random-normal xcor prod-noise
        set ycor random-normal ycor prod-noise
        
        let guess guess-meaning self
        ask hearer [ 
          set guesses-history (sentence guesses-history ifelse-value (guess = [meaning] of myself) [1] [0])
          if length guesses-history > 20 [
            set guesses-history remove-item 0 guesses-history
          ]
        ]
        ;; show [guesses-history] of hearer
        
        ifelse (random 100 < forget-missed) and not (guess = meaning) [ 
          ;; if miss-communicated, then nobody remembers it
          ;;show (list "Fail!" guess meaning)
          die 
        ]
        [ ;; otherwise, they both remember it with some categorization bias
          ;; duplicate in speaker
          hatch-exemplars 1 [
            set owner talker
            set hidden? not (showing = [who] of owner)
              
            cat-percept self
            set shape meaning-to-shape meaning
          ]
            
          cat-percept self
          set shape meaning-to-shape meaning
          ;;show (list speaker talker owner hearer label [label] of talker )
        ] 
      ]
      
      if speaker = nobody [
         ;; this was an imagined exemplar
         die
      ]
    ]
  ]
  
  ask people [
    set exemplar-set exemplars with [owner = myself]
  ]
end

to-report guess-meaning [ex]
  ;; try to guess meaning based on the nearest neighbor of ex
  let guess -1
  ask ex [
    let cohort ([exemplar-set] of owner)
    let subcohort (cohort with [speaker = [speaker] of myself ])
    ifelse ( random 100 < perc-alignment  ;; if we are paying attention to how they've said stuff before
      and (count subcohort > 1) ) ;; and we have heard them say a few 
    [ ;; then guess based on what we heard them say before
      let nn min-one-of subcohort [ distance myself ]
      set guess [meaning] of nn
      ;; ask nn [ show distance ex ]
    ]
    [  ;; otherwise just categorize according to all the exemplars we know
      ifelse (count cohort) > 0 [
        let nn min-one-of cohort [ distance myself ]
        set guess [meaning] of nn
        ;; ask nn [ show distance ex ]
      ]
      [ ;; if we didn't have any exemplars, just make something up
        set guess random length lexicon
      ]      
    ]
  ]
  
  report guess
end
    

to-report get-source-exemplar [ hearer ]
  ;; ask the hearer to find one of their neighbors' exemplars, to be copied
  let ex-src nobody
  
  ask hearer [
    
    ask one-of link-neighbors [
      let talker self

      let meaning-cat random length lexicon
      
      ifelse ( random 100 < prod-alignment )
      [
        ifelse (count exemplar-set with [speaker = hearer and meaning = meaning-cat]) > 0
        [ 
          ;; if possible, the talker recalls an exemplar spoken by the hearer
          set ex-src one-of exemplar-set with [speaker = hearer and meaning = meaning-cat]
        ]
        [
          if (count exemplar-set with [meaning = meaning-cat]) > 0 
          [
            ;; next best is to recall an exemplar spoken by the talker
            set ex-src one-of exemplar-set with [speaker = talker and meaning = meaning-cat]
          ]
        ]
      ]
      [
        if (count exemplar-set with [meaning = meaning-cat]) > 0
        [
          ;; if possible, find a historical exemplar with this meaning
          set ex-src one-of exemplar-set with [meaning = meaning-cat]
        ]
      ]
      
      if (ex-src = nobody) ;; none of the above applied, so we just hallucinate one
      [
        hatch-exemplars 1 [ 
          set meaning meaning-cat
          set owner talker
          set speaker nobody ;; label this as imaginary, so we can kill it when we're done
          setxy random-xcor random-ycor
          set ex-src self
          ]
      ]
      ;; to-do: option to select optimal exemplar
      
    ]
  ]
  report ex-src
end
     

  
to cat-percept [ ex ]
  ;; categorical perception bias
  let cohort (([exemplar-set] of owner) with [meaning = [meaning] of ex])
  if count cohort > 0 [
    let nearest min-one-of cohort [ distance ex ]
    ;; show (list meaning self cohort with [meaning = [meaning] of self])
    ask ex [
      set xcor xcor + ([xcor] of nearest - xcor) * cat-percept-bias / 100 
      set ycor ycor + ([ycor] of nearest - ycor) * cat-percept-bias / 100 
    ]
  ]
end
  
  
to speak 
  ask people [
    ;; make an exemplar based on your own exemplar set
    hatch-exemplars 1 [
      set speaker myself
      set owner myself
      set hidden? not (showing = [who] of speaker)
      set label [who] of speaker 
      
      let lex random length lexicon ;; choose a random semantic category
      set meaning lex
      
      ;; look at the collection of old exemplars from that semantic category
      let cohort ([exemplar-set] of owner) with [meaning = lex]
    
      ;; if you have some of this category, copy it with noise
      ifelse count cohort > 0
      [
        ;; production around an exemplar
        let ex one-of cohort
        setxy ([xcor] of ex) ([ycor] of ex)
        ;; or production around the mean
        ;; setxy [(mean [xcor] of cohort) (mean [ycor] of cohort)]
        
        ;; add production noise
        set xcor random-normal xcor prod-noise
        set ycor random-normal ycor prod-noise
        
        ;; categorical perception bias: nudge toward nearest matching exemplar
        cat-percept self
      ]
      [ ;; when there isn't anything in this category, just pick something random
        setxy random-xcor random-ycor
      ]
    
      set shape meaning-to-shape meaning
    ]
    set exemplar-set exemplars with [owner = myself] 
  ]
end
    
to listen  ;; incorporate a random exemplar with unknown meaning
  ask people [
    hatch-exemplars 1 [
      ;; speaker variable is left unset
      set owner myself
      let ex self
      set hidden? not (showing = [who] of myself)
      set label "-"
        
      setxy random-xcor random-ycor ;; hear a token from a random point in the form space
      
      let cohort ([exemplar-set] of owner) ;; this doesn't include self
      ;;show cohort
      set meaning [meaning] of min-one-of cohort [ distance ex ]
      set color 5 ;; gray
      set shape meaning-to-shape meaning
        
      ;; categorical perception bias: nudge toward nearest matching exemplar
      cat-percept self
    ]
    set exemplar-set exemplars with [owner = myself] ;; update
  ]    
end



to-report meaning-to-shape [ index ]
  report item index lexicon
end


;******************************;
;  Change which person shows
;******************************;

to next-person 
  ifelse showing = "net" [
    ask people [ hide-turtle ]
    ask links [ hide-link ]
  ]
  [
    ask (person showing) [hide-turtle]
    ask ([exemplar-set] of person showing) [ hide-turtle ]
  ] 
   
  ifelse showing = ( num-people - 1 ) [
    set showing "net"
    ask people [ show-turtle ]
    ask links [ show-link ]
  ] 
  [
    ifelse showing = "net" [
      set showing 0
    ] [
      set showing (showing + 1)
    ]
    ask person showing [ show-turtle ]
    ask ([exemplar-set] of person showing) [ show-turtle ]
  ]
end

to prev-person 
  ifelse showing = "net" [
    ask people [ hide-turtle ]
    ask links [ hide-link ]
  ]
  [
    ask (person showing) [hide-turtle]
    ask ([exemplar-set] of person showing) [ hide-turtle ]
  ] 
   
  ifelse showing = 0 [
    set showing "net"
    ask people [ show-turtle ]
    ask links [ show-link ]
  ] 
  [
    ifelse showing = "net" [
      set showing ( num-people - 1 )
    ] [
      set showing (showing - 1)
    ]
    ask person showing [ show-turtle ]
    ask ([exemplar-set] of person showing) [ show-turtle ]
  ]
end

;******************************;
;  Plotting
;******************************;

to do-plots
  let summin 0
  let summax 0
  ask people [

    let minvar 0
    let maxvar 0
    foreach n-values (length lexicon) [?] [
      let ex-set (exemplar-set with [meaning = ?])
      ;; assuming there are exemplars with this meaning, add it on to the accumulated variance
      ;; the divergence measure here is the minimum distance to another exemplar of the same meaning
      if count ex-set > 1 [
        set minvar minvar + ( mean ([distance min-one-of other ex-set [distance myself]] of ex-set)) ^ 2
        set maxvar maxvar + ( mean ([distance max-one-of other ex-set [distance myself]] of ex-set)) ^ 2
      ]
    ]

    let minsd (sqrt minvar) / length lexicon
    set summin summin + minsd      
    set-current-plot "category min-dist divergence"
    if plot-pen-exists? word "person " who [
      set-current-plot-pen word "person " who
      set-plot-pen-color color
      plot minsd
    ]
    
    let maxsd (sqrt maxvar) / length lexicon
    set summax summax + maxsd            
    set-current-plot "category max-dist divergence"
    if plot-pen-exists? word "person " who [
      set-current-plot-pen word "person " who
      set-plot-pen-color color
      plot maxsd
    ]
  ]

  set-current-plot "category min-dist divergence"
  set-current-plot-pen "mean"
  plot summin / (count people)
  set-current-plot "category max-dist divergence"
  set-current-plot-pen "mean"
  plot summax / (count people)  

  ask links [
    ;; set the label of each link to the euclidean distance between
    ;; the centers of all the categories of the two people
    let p1 min-one-of both-ends [who]
    let p2 max-one-of both-ends [who]
    let dsqr 0
    foreach n-values (length lexicon) [?] [
      ;; the two set of exemplars with this meaning
      let ex-set1 ([exemplar-set] of p1) with [meaning = ?]
      let ex-set2 ([exemplar-set] of p2) with [meaning = ?]
      
      ;; assuming both people have such exemplars, accumulate the squared distances,
      ;; where we take a mean of cross-cluster minimum distances as a typical distance
      if count ex-set1 > 0 and count ex-set2 > 0 [
        let mindists (sentence [distance min-one-of ex-set1 [distance myself]] of ex-set2
                               [distance min-one-of ex-set2 [distance myself]] of ex-set1 )
        set dsqr dsqr + (mean mindists) ^ 2
      ]
    ]
    ;; convert the squared differences into a linear distance, with integer precision
    set label precision ((sqrt dsqr) / length lexicon) 1
  ]
  
  set-current-plot "people min-dist divergence"
  let divtot 0
  ask people [
    let div (sum [label] of my-links) / count my-links
    set divtot divtot + div
    if plot-pen-exists? word "person " who [
      set-current-plot-pen word "person " who
      set-plot-pen-color color
      plot div
    ]
  ]
  set-current-plot-pen "mean"
  plot divtot / count people
  
  if hear-neighbors [
    ask people [
      set label (word who ": " ( precision ( sum guesses-history / length guesses-history * 100 ) 0 ) "%" )
    ]
  ]
  
end


;******************************;
;  License
;******************************;
;; This simulation was made by Lucien Carroll <lucien@ling.ucsd.edu>. It is educational software, 
;; created for learning and sharing understanding, and modification with attribution is encouraged. 
;; The license for the NetLogo demos (which this simulation is somewhat based on) reads:
;;
;; "NetLogo is Copyright 1999-2009 by Uri Wilensky. All rights reserved."
;;
;; "The NetLogo software, models and documentation are distributed free of
;; charge for use by the public to explore and construct
;; models. Permission to copy or modify the NetLogo software, models and
;; documentation for educational and research purposes only and without
;; fee is hereby granted, provided that this copyright notice and the
;; original author's name appears on all copies and supporting
;; documentation. For any other uses of this software, in original or
;; modified form, including but not limited to distribution in whole or
;; in part, specific prior permission must be obtained from Uri
;; Wilensky. The software, models and documentation shall not be used,
;; rewritten, or adapted as the basis of a commercial software or
;; hardware product without first obtaining appropriate licenses from Uri
;; Wilensky. We make no representations about the suitability of this
;; software for any purpose. It is provided "as is" without express or
;; implied warranty."
@#$#@#$#@
GRAPHICS-WINDOW
667
12
1037
403
16
16
10.91
1
10
1
1
1
0
1
1
1
-16
16
-16
16
0
0
1
ticks

BUTTON
182
161
248
194
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL

SLIDER
5
337
151
370
forget-rate
forget-rate
0
.1
0.015
.001
1
NIL
HORIZONTAL

BUTTON
183
291
246
324
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL

SLIDER
5
375
151
408
prod-noise
prod-noise
0
5
1
.1
1
NIL
HORIZONTAL

SLIDER
10
213
164
246
num-people
num-people
2
20
4
1
1
NIL
HORIZONTAL

SLIDER
10
137
164
170
links-per-person
links-per-person
1
2
2
.01
1
NIL
HORIZONTAL

SLIDER
10
175
164
208
pref-attach
pref-attach
0
100
50
1
1
NIL
HORIZONTAL

BUTTON
184
195
249
228
NIL
layout
T
1
T
OBSERVER
NIL
NIL
NIL
NIL

BUTTON
606
27
661
60
next
next-person
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL

MONITOR
550
18
604
67
NIL
showing
17
1
12

SWITCH
5
300
152
333
hear-neighbors
hear-neighbors
0
1
-1000

TEXTBOX
63
119
117
137
Network
12
0.0
1

TEXTBOX
54
278
115
296
Exemplars
12
0.0
1

BUTTON
494
27
549
60
prev
prev-person
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL

PLOT
281
200
665
324
category min-dist divergence
NIL
NIL
0.0
10.0
0.0
1.0
true
true
PENS
"mean" 1.0 0 -16777216 true
"person 0" 1.0 0 -1 true
"person 1" 1.0 0 -1 true
"person 2" 1.0 0 -1 true
"person 3" 1.0 0 -1 true
"person 4" 1.0 0 -1 true

SLIDER
153
374
279
407
prod-alignment
prod-alignment
0
100
90
1
1
NIL
HORIZONTAL

SLIDER
5
410
150
443
cat-percept-bias
cat-percept-bias
0
100
0
1
1
NIL
HORIZONTAL

SLIDER
153
410
279
443
forget-missed
forget-missed
0
100
60
1
1
NIL
HORIZONTAL

SLIDER
153
337
278
370
perc-alignment
perc-alignment
0
100
90
1
1
NIL
HORIZONTAL

PLOT
281
78
666
202
people min-dist divergence
NIL
NIL
0.0
10.0
0.0
1.0
true
true
PENS
"mean" 1.0 0 -16777216 true
"person 0" 1.0 0 -1 true
"person 1" 1.0 0 -1 true
"person 2" 1.0 0 -1 true
"person 3" 1.0 0 -1 true
"person 4" 1.0 0 -1 true

BUTTON
182
257
245
290
NIL
reset
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL

TEXTBOX
10
9
478
103
This model is designed to show dialect variation across a social net.\n1. Create a network hitting [setup]. Press [layout] until spread out.\n2. When the [go] button is pressed, the people exchange simple signs (2D vectors associated with categorical meanings).\n3. The [showing] buttons toggle between views of the network and each person's exemplar space.\nFor further info, see Information tab.
10
0.0
1

PLOT
281
323
665
447
category max-dist divergence
NIL
NIL
0.0
10.0
0.0
1.0
true
true
PENS
"mean" 1.0 0 -16777216 true
"person 0" 1.0 0 -1 true
"person 1" 1.0 0 -1 true
"person 2" 1.0 0 -1 true
"person 3" 1.0 0 -1 true
"person 4" 1.0 0 -1 true

@#$#@#$#@
WHAT IS IT?
-----------
This model is meant to model speaker variation in a simple linguistic system. The speakers interact according to a social network, exchanging signs which consist of two-dimensional vector forms associated with categorical meanings.

HOW IT WORKS
------------
The buttons and parameters in the upper "Network" group establish a sparse social network on the continuum between a preferential attachment network (as found in the Language Change demo in the models library) and a randomly linked network. (Note that this is not a conventional random graph -- each node has at least one edge, and for each edge the partner is chosen randomly.) 

When hear-neighbors is set to [On], the people take turns selecting a speaking partner, and they attempt a communication event. The speaker chooses a point in 2-D space and a categorical meaning (associated with a shape), generally a noisy copy of a previous sign. The hearer attempts to guess the meaning, and if all goes well, both the speaker and the hearer store a memory of the event.

When hear-neighbors is set to [Off], the people take turns producing and categorizing random signs, each independent of the other people. Each person establishes their own meaning space because of the production and categorization processes, without any actual interaction.

HOW TO USE IT
-------------

Network Section:
 - links-per-person: ratio of links to people, except sometimes duplicate links are produced, which are reduced to one link
 - pref-attach: the degree of preferential attachment bias. 0 is a randomly linked graph, and 100 is a preferential attachment graph as in the Language Change model
 - num-people: number of speakers in the network
 - setup: initialize the social network
 - layout: untangle the network into a spring layout

Exemplars Section:
 - hear-neighbors: interact with neighbors rather than jabber to yourself
 - forget-rate: rate at which exemplars randomly die
 - prod-noise: standard deviation of gaussian noise when reproducing a vector
 - cat-percept-bias: degree of categorical perception bias. 0 leaves the exemplar's vector as it was heard, and 100 moves the vector to match the nearest neighbor's vector
 - perc-alignment: probability that the hearer will use a perception strategy based on previous experience with that speaker
 - prod-alignment: probability that the speaker will use a production strategy based on previous experience with that hearer
 - forget-missed: probability that an incorrectly guessed exemplar will be stored
 - reset: erase all the exemplars
 - go: make the speakers produce exemplars

Plots
 - divergences: Measuring across speakers, people min-dist divergence is the mean distance between one speaker's exemplars and the closest exemplars of the same meaning in their neighbors' exemplar spaces. Within speakers, category min-dist divergence is the mean distance between an exemplar and the closest exemplar of the same meaning, and category max-dist divergence is the mean distance between an exemplar and the farthest exemplar of the same meaning.
 - showing = net: The speaker social network. Labels on links are the min-dist divergences along those links. Labels on people consist of their ID number and the accuracy of their last 20 meaning categorization guesses.
 - showing = ID numbers: The exemplar space of the person with the indicated ID number. In the plot, shapes indicate the meaning category, and position in space represents the two dimensions of the sign's vector. The labels and colors correspond to the speaker in the event that created that exemplar.


THINGS TO NOTICE
----------------
This section could give some ideas of things for the user to notice while running the model.


THINGS TO TRY
-------------
This section could give some ideas of things for the user to try to do (move sliders, switches, etc.) with the model.


EXTENDING THE MODEL
-------------------
This section could give some ideas of things to add or change in the procedures tab to make the model more complicated, detailed, accurate, etc.


NETLOGO FEATURES
----------------
This section could point out any especially interesting or unusual features of NetLogo that the model makes use of, particularly in the Procedures tab.  It might also point out places where workarounds were needed because of missing features.


RELATED MODELS
--------------
NetLogo Model Library > Social Science > (unverified) > Language Change


CREDITS AND REFERENCES
----------------------
This section could contain a reference to the model's URL on the web if it has one, as well as any other necessary credits or references.
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

ant
true
0
Polygon -7500403 true true 136 61 129 46 144 30 119 45 124 60 114 82 97 37 132 10 93 36 111 84 127 105 172 105 189 84 208 35 171 11 202 35 204 37 186 82 177 60 180 44 159 32 170 44 165 60
Polygon -7500403 true true 150 95 135 103 139 117 125 149 137 180 135 196 150 204 166 195 161 180 174 150 158 116 164 102
Polygon -7500403 true true 149 186 128 197 114 232 134 270 149 282 166 270 185 232 171 195 149 186
Polygon -7500403 true true 225 66 230 107 159 122 161 127 234 111 236 106
Polygon -7500403 true true 78 58 99 116 139 123 137 128 95 119
Polygon -7500403 true true 48 103 90 147 129 147 130 151 86 151
Polygon -7500403 true true 65 224 92 171 134 160 135 164 95 175
Polygon -7500403 true true 235 222 210 170 163 162 161 166 208 174
Polygon -7500403 true true 249 107 211 147 168 147 168 150 213 150

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

die 1
false
0
Rectangle -7500403 true true 45 45 255 255
Circle -16777216 true false 129 129 42

die 2
false
0
Rectangle -7500403 true true 45 45 255 255
Circle -16777216 true false 69 69 42
Circle -16777216 true false 189 189 42

die 3
false
0
Rectangle -7500403 true true 45 45 255 255
Circle -16777216 true false 69 69 42
Circle -16777216 true false 129 129 42
Circle -16777216 true false 189 189 42

die 4
false
0
Rectangle -7500403 true true 45 45 255 255
Circle -16777216 true false 69 69 42
Circle -16777216 true false 69 189 42
Circle -16777216 true false 189 69 42
Circle -16777216 true false 189 189 42

die 5
false
0
Rectangle -7500403 true true 45 45 255 255
Circle -16777216 true false 69 69 42
Circle -16777216 true false 129 129 42
Circle -16777216 true false 69 189 42
Circle -16777216 true false 189 69 42
Circle -16777216 true false 189 189 42

die 6
false
0
Rectangle -7500403 true true 45 45 255 255
Circle -16777216 true false 84 69 42
Circle -16777216 true false 84 129 42
Circle -16777216 true false 84 189 42
Circle -16777216 true false 174 69 42
Circle -16777216 true false 174 129 42
Circle -16777216 true false 174 189 42

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

rabbit
false
0
Polygon -7500403 true true 61 150 76 180 91 195 103 214 91 240 76 255 61 270 76 270 106 255 132 209 151 210 181 210 211 240 196 255 181 255 166 247 151 255 166 270 211 270 241 255 240 210 270 225 285 165 256 135 226 105 166 90 91 105
Polygon -7500403 true true 75 164 94 104 70 82 45 89 19 104 4 149 19 164 37 162 59 153
Polygon -7500403 true true 64 98 96 87 138 26 130 15 97 36 54 86
Polygon -7500403 true true 49 89 57 47 78 4 89 20 70 88
Circle -16777216 true false 37 103 16
Line -16777216 false 44 150 104 150
Line -16777216 false 39 158 84 175
Line -16777216 false 29 159 57 195
Polygon -5825686 true false 0 150 15 165 15 150
Polygon -5825686 true false 76 90 97 47 130 32
Line -16777216 false 180 210 165 180
Line -16777216 false 165 180 180 165
Line -16777216 false 180 165 225 165
Line -16777216 false 180 210 210 240

sheep
false
0
Rectangle -7500403 true true 151 225 180 285
Rectangle -7500403 true true 47 225 75 285
Rectangle -7500403 true true 15 75 210 225
Circle -7500403 true true 135 75 150
Circle -16777216 true false 165 76 116

spider
true
0
Polygon -7500403 true true 134 255 104 240 96 210 98 196 114 171 134 150 119 135 119 120 134 105 164 105 179 120 179 135 164 150 185 173 199 195 203 210 194 240 164 255
Line -7500403 true 167 109 170 90
Line -7500403 true 170 91 156 88
Line -7500403 true 130 91 144 88
Line -7500403 true 133 109 130 90
Polygon -7500403 true true 167 117 207 102 216 71 227 27 227 72 212 117 167 132
Polygon -7500403 true true 164 210 158 194 195 195 225 210 195 285 240 210 210 180 164 180
Polygon -7500403 true true 136 210 142 194 105 195 75 210 105 285 60 210 90 180 136 180
Polygon -7500403 true true 133 117 93 102 84 71 73 27 73 72 88 117 133 132
Polygon -7500403 true true 163 140 214 129 234 114 255 74 242 126 216 143 164 152
Polygon -7500403 true true 161 183 203 167 239 180 268 239 249 171 202 153 163 162
Polygon -7500403 true true 137 140 86 129 66 114 45 74 58 126 84 143 136 152
Polygon -7500403 true true 139 183 97 167 61 180 32 239 51 171 98 153 137 162

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

squirrel
false
0
Polygon -7500403 true true 87 267 106 290 145 292 157 288 175 292 209 292 207 281 190 276 174 277 156 271 154 261 157 245 151 230 156 221 171 209 214 165 231 171 239 171 263 154 281 137 294 136 297 126 295 119 279 117 241 145 242 128 262 132 282 124 288 108 269 88 247 73 226 72 213 76 208 88 190 112 151 107 119 117 84 139 61 175 57 210 65 231 79 253 65 243 46 187 49 157 82 109 115 93 146 83 202 49 231 13 181 12 142 6 95 30 50 39 12 96 0 162 23 250 68 275
Polygon -16777216 true false 237 85 249 84 255 92 246 95
Line -16777216 false 221 82 213 93
Line -16777216 false 253 119 266 124
Line -16777216 false 278 110 278 116
Line -16777216 false 149 229 135 211
Line -16777216 false 134 211 115 207
Line -16777216 false 117 207 106 211
Line -16777216 false 91 268 131 290
Line -16777216 false 220 82 213 79
Line -16777216 false 286 126 294 128
Line -16777216 false 193 284 206 285

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270

@#$#@#$#@
NetLogo 4.1
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 1.0 0.0
0.0 1 1.0 0.0
0.2 0 1.0 0.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180

@#$#@#$#@
0
@#$#@#$#@
