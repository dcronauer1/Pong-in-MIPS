#Bitmap Display: 4x4 unit, 512x512 display, 0x10040000 address
#Keyboard and Display MMIO is required for I/O

.data
BaseAddress: .word 0x10040000
ColorTable:
	.word 0x000000		#black - background
	.word 0xffffff		#white - ui color
	.word 0x367fc7		#blueish - paddle color
	.word 0xffa500		#orange - ball color
	.word 0xffffff		#white - middle line color
	.word 0xbbbbbb		#light grey - pong color
	.word 0xcfde4b		#yellow - score
#number data stuff:
Digits: .byte 6,6,0,51,116 #maxdigits,color,bg color,xoffset for p0,x offset for p1
digitBuffer: .space 7	#also need null terminator
DigitTable:
        .byte   ' ', 0,0,0,0,0,0,0,0,0,0,0,0
        .byte   '0', 0x7e,0xff,0xc3,0xc3,0xc3,0xc3,0xc3,0xc3,0xc3,0xc3,0xff,0x7e
        .byte   '1', 0x38,0x78,0xf8,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x18
        .byte   '2', 0x7e,0xff,0x83,0x06,0x0c,0x18,0x30,0x60,0xc0,0xc1,0xff,0x7f
        .byte   '3', 0x7e,0xff,0x83,0x03,0x03,0x1e,0x1e,0x03,0x03,0x83,0xff,0x7e
        .byte   '4', 0xc3,0xc3,0xc3,0xc3,0xc3,0xff,0x7f,0x03,0x03,0x03,0x03,0x03
        .byte   '5', 0xff,0xff,0xc0,0xc0,0xc0,0xfe,0x7f,0x03,0x03,0x83,0xff,0x7f
        .byte   '6', 0xc0,0xc0,0xc0,0xc0,0xc0,0xfe,0xfe,0xc3,0xc3,0xc3,0xff,0x7e
        .byte   '7', 0x7e,0xff,0x03,0x06,0x06,0x0c,0x0c,0x18,0x18,0x30,0x30,0x60
        .byte   '8', 0x7e,0xff,0xc3,0xc3,0xc3,0x7e,0x7e,0xc3,0xc3,0xc3,0xff,0x7e
        .byte   '9', 0x7e,0xff,0xc3,0xc3,0xc3,0x7f,0x7f,0x03,0x03,0x03,0x03,0x03
        .byte   'P', 0xfe,0xff,0xc3,0xc3,0xc3,0xff,0xfe,0xc0,0xc0,0xc0,0xc0,0xc0
        .byte   'O', 0x7e,0xff,0xc3,0xc3,0xc3,0xc3,0xc3,0xc3,0xc3,0xc3,0xff,0x7e
        .byte   'N', 0xc3,0xe3,0xe3,0xf3,0xf3,0xdb,0xdb,0xcf,0xcf,0xc7,0xc7,0xc3
        .byte   'G', 0x7e,0xff,0xc3,0xc0,0xc0,0xc0,0xcf,0xcf,0xc3,0xc3,0xff,0x7e

topOfScreenY: .byte 37	#dont forget unsigned (make sure this is an even number

scores: .word 0,0#player 0,1 scores. make sure theyre unsigned
scoreToWin:.word 10
ballLastColor: .word 0x00

#ball's x,y,x vel,y velocity,initial movement delay,min delay.
ballMovement: .byte 63,82,1,-1,18,5#Velocities can be negative!
#1110 1110 1101 1011 0110 1010 1010 1001 0010 0100 1001 0001, but loop last 4 bits
Dampener: .byte 0xEE,0xDB,0x6A,0xA9,0x24,0x91
DampenerPos: .byte 0,7,0,7#which byte,bit positioner(0-7),static,static
#player 0y,1y,length,0xpos,1xpos,thickness (0 index).
  #"perfect" x positions are 21 and 107
  #paddle length needs to be odd and 3<=len<screen height-topOfScreenY (89 currently)
playerPositions: .byte 78,78,9,11,117,2#unsigned!!. y positions are top of paddle

lastPressedKey: .byte 0,0,0#key in ascii,direction,speed (0,1)	
#movement opportunity out of 20 to move fast (higher=tougher)
player1Ai:	.byte 13,0#2nd byte is mess up chance (out of 100)

difficultyTable:
#ball initial movement delay,min delay,player1 ai level (0-20),p1 chance to not move (0-100),Paddle Height (3-89,odd)
	.byte  30,14,5,25,13	#0
	.byte  23,12,12,20,11	#1
	.byte  20,8,16,10,9	#2
	.byte  16,6,20,0,9	#3

pong:  .asciiz "PONG"
msgWin:	.asciiz "You win!"
msgEnterDifficulty: .asciiz "Enter Difficulty (0-3, other=custom): "
msgEnterParams0: .asciiz "Enter initial ball movement delay(ms)(1-40):"
msgEnterParams1: .asciiz "Min delay(ms)(1-40): "
msgEnterParams2: .asciiz "CPU ai level(0-20): "
msgEnterParams3: .asciiz "CPU chance to not move(0-100): "
msgEnterParams4: .asciiz "paddle height(odd,3-89): "
msgEnterMaxScore: .asciiz "Enter points needed to win (0=infinite): "
msgPromptContinue: .asciiz "Continue Playing? Yes=1: "
msgPlayerWon: .asciiz "Player "," Won!\n"
invalidNum: .asciiz "Invalid Num, Try Again\n"
controlsPrompt: .asciiz "===============\nControls:\nW: up (shift+W=fast)\nS: down (shift+S=fast)\nOther: Stop moving\n===============\n"

#tempthingy: .byte 38 #used for control spawning the ball

.text
main: 
#handles program execution
#code above mainLoop handles starting a new game
#mainLoop handles each round
#mainGameLoop handles the game itself
#mainWonGame is self explanatory

  #Enable interrupts globally
  mfc0 $t0, $12
  ori $t0, $t0, 0x0001
  mtc0 $t0, $12
  
  #reset some of the params
  li $t0,1
  sb $t0,ballMovement+2		#reset x velocity
  sb $0,ballLastColor	#probably unnecessary
  sb $0,lastPressedKey
  sb $0,lastPressedKey+1
  sb $0,lastPressedKey+2	#reset last pressed key stuff
  sb $0,scores
  sb $0,scores+4		#reset scores
  
  sw $0, 0xffff0004		#clear the stored key
  
  jal UserInputParameters	#get params for new game
  jal DrawGraphicsInitial	#draw initial UI
mainLoop:#loop for the entire game (until there is a winner)
  #below is for preround, so runs after a score
  
  #check if someone won and handle it if they did
  jal mainWonGame#(sub procedure, but return if nobody won)
  
  li $t0,82
  sb $t0,ballMovement+1		#set ball y to center
  
  lbu $s4,ballMovement+4	#initial ball speed
  lbu $s1,ballMovement+5	#min ball speed
  
  #move ball dampener initials back over
  lbu $t0,DampenerPos+2
  lbu $t1,DampenerPos+3
  sb $t0,DampenerPos
  sb $t1,DampenerPos+1
  
  #get time + sleep delay here, store in $s3
  li $v0,30
  syscall	#get time
  move $s3,$a0	#store new time
  addiu $s3,$s3,2000		#2 second delay
  move $s7,$a0
  move $s6,$a0
  move $s5,$a0
  move $s0,$a0	#fixed bug where sometimes each block couldnt be accessed
  mainPreroundSleep:#this still lets players have control before the ball is served
  #get new time in $s2
  li $v0,30
  syscall		#get time
  move $s2,$a0	#store new time (for checking if we need to do ball stuff below)
  bleu $s2,$s3,mainGameLoop#if branch, still preround
    #no branch, start new round (preround over)
  jal StartRound	#serve a ball
  
 mainGameLoop:
  #s0: store time for ball collision
  #s1: min ball delay (from ballMovement+5), used with $s4
  #s2: time to compare with $s3 (for preround)
  #s3: time to sleep until (for preround)
  #s4: for wall bounce delay (counts down)
  #s5: store time for player0 movement
  #s6: ^ for player1 ai
  #s7: ^ for ball movement
  
  #handle player 0 movement here
    li $v0,30
    syscall 	#get time
    bltu $a0,$s5,mainNoPlayerMovement
      #player movement on an interval (different hard coded delays for fast/slow)
      #Note: im not using the exception handler for keyboard inputs anymore, it was causing issues
      lw $a0, 0xffff0004	#load last pressed key
      jal Player0Handling	#handle if and how to move p0
      #v1 returns the speed (1 for fast)
      andi $v1,0x01	#mask out bits just incase
      li $t0,8		#fast number
      xori $v1,0x01	#flip bit of v1
      mul $t1,$v1,7	#slow number
      addu $t0,$t0,$t1	#15 if slow, 8 if fast
      
      li $v0,30
      syscall		#get time
      move $s5,$a0	#store new time
      addu $s5,$s5,$t0	#add time in ms till next movement
    mainNoPlayerMovement:
    
  #handle player 1 ai here
    li $v0,30
    syscall 			#get time
    bltu $a0,$s6,mainNoPlayer1Movement
      #player ai movement on an interval (different interval depending on speed)
      jal Player1AI		#decide where and how fast to move p1
      
      #v1 returns fast/slow (1/0)
      andi $v1,0x01	#mask out bits just incase
      li $t0,8		#fast number
      xori $v1,0x01	#flip bit of v1
      mul $t1,$v1,10	#slow number
      addu $t0,$t0,$t1	#18 if slow, 8 if fast
      
      li $v0,30
      syscall		#get time
      move $s6,$a0	#store new time
      addu $s6,$s6,$t0	#add time in ms till next movement
    mainNoPlayer1Movement:
    
    bleu $s2,$s3,mainPreroundSleep #if its still preround, then skip ball stuff   
    
  #handle ball movement here
    li $v0,30
    syscall 			#get time
    bltu $a0,$s7,mainNoBallMovement
      #move the ball on an interval
      li $a0,1	#bool to move the ball
      jal BallMovement
      bne $v0,1,mainNoScored
        move $a0,$v1	#which player
        jal PlayerScored
        b mainLoop	#start a new round
      mainNoScored:
      beqz $a3,mainBallNoSpeedChange#a3 is return from BallMovement
        ble $s4,$s1,mainBallNoSpeedChange#current cant be below min
          jal BallSpeedDampener#determine if speed should be reduced
          subu $s4,$s4,$v0#subtract 0 or 1
      mainBallNoSpeedChange:
      #branch here when current<=min delay
      #or no speed change
      li $v0,30
      syscall		#get time
      move $s7,$a0	#store new time
      addu $s7,$s7,$s4	#add time in ms till next movement
    mainNoBallMovement:
    
  #handle ball player collisions here:
  ble $s4,7,mainNoBallCollisionCheck#dont check if movement delay <=7
  
    li $v0,30
    syscall 			#get time
    bltu $a0,$s0,mainNoBallCollisionCheck 
    #check if ball is close to paddles
    lb $t1,playerPositions+3#p0 x
    lb $t2,playerPositions+4#p1 x
    lb $t0,ballMovement#ball x
    addiu $t1,$t1,1
    subiu $t2,$t2,1
    ble $t0,$t1,mainCheckBallCollision#ball x<=p0x+1
    bge $t0,$t2,mainCheckBallCollision#ball x>=p1x-1
    b mainNoBallCollisionCheck #ball still in inner field
    mainCheckBallCollision:
      li $a0,0	#bool to not move the ball
      jal BallMovement#check collisions with players
      #impossible to score if it can only move from a player collision
      #dont change the speed from a collision check
      li $v0,30
      syscall		#get time
      move $s0,$a0	#store new time
      addiu $s0,$s0,7	#add time in ms till next collision check
      ##only check as fast as the players can move##
    mainNoBallCollisionCheck:
    
    b mainGameLoop	#restart game loop here

 mainWonGame:
#sub procedure to check for and handle if a player wins the game, and if the player wants
# to play another game 
  lw $t0,scoreToWin
  lw $t1,scores
  lw $t2,scores+4
  beqz $t0,mwgInfinite#if ScoreToWin=0, then game is infinite
  add $t3,$0,$0#player 0
  bgeu $t1,$t0,mwgPlayerWon#check if p0 won
  addi $t3,$0,1#player 1
  bgeu $t2,$t0,mwgPlayerWon#check if p1 won
  #else, nobody won
  mwgInfinite:
  jr $ra#nobody won, return
  
  mwgPlayerWon:  #a player won ($t3=player)
  #print "Player [$t3] Won!"
  la $a0,msgPlayerWon
  li $v0,4	#print string
  syscall	#"Player "
  jal PrintToKeyBoardMMIO #print to mmio
  move $a0,$t3	#player number
  addiu $a0,$a0,1#make num 1 or 2
  li $v0,1
  syscall 	#print player num
  
  move $t7,$a0
  la $a0,scores
  addiu $t7,$t7,0x30	#make it ascii num
  sw $t7,($a0)	#need a memory address for belo
  jal PrintToKeyBoardMMIO #print to mmio
  
  la $a0,msgPlayerWon+8
  li $v0,4	#print string
  syscall	#" Won!"	
  jal PrintToKeyBoardMMIO #print to mmio
  
  li $a0,2000
  jal pause	#pause for 2 seconds
  
  la $a0,msgPromptContinue
  li $v0,4	#print string
  syscall	#"Continue Playing? No=0 Yes=1:"
  jal PrintToKeyBoardMMIO #print to mmio
  
  jal GetNumsFromKeyboardSim	#get continue playing int
  beq $v0,1,mainContinuePlaying
    #player chose to end the game (or entered something other than 1)	
    li $v0, 10			#Exit syscall
    syscall	#stop program
  mainContinuePlaying:
  j main#restart the game

#end main

BallSpeedDampener:
#procedure to dampen the speed of the ball (instead of subtracting 1ms every time)
#take a series of hex bytes, and uses their binary config to determine if
# it should sub by 1 or 0
#output $v0: what to subtract from current delay (0 or 1)

  lbu $t0,DampenerPos	#get the current byte position
  lbu $t1,DampenerPos+1 #get the bit selector
  lbu $v0,Dampener($t0)	#get the byte
  srlv $v0,$v0,$t1	#get bit in position
  andi $v0,0x01		#mask out other bits
  subi $t1,$t1,1	#get next byte ready
  bgez $t1,bsdDone	#not through all bytes yet
    #if here, then get next byte ready
    li $t1,7
    addiu $t0,$t0,1
    blt $t0,6,bsdNotAtLastByte
      #if here, then only look at last 4 bytes (0001)
      li $t1,3
      li $t0,5	#be at the last byte
    bsdNotAtLastByte:  
    sb $t0,DampenerPos#store the position
  bsdDone:
  sb $t1,DampenerPos+1#store the new bit selector
  #output is $v0= 0 or 1 
  jr $ra
#end BallSpeedDampener

BallMovement:
#procedure to handle: checking ball collisions, updating ball velocity, and updating ball position
#checks collisions with top and bottom, players, and goals
#IMPORTANT: procedure uses t registers throughout
#input $a0: bool for if ball should move if it doesnt collide w/ player
#output $v0: 1 for if there was a score
#output $v1: which player scored (if $v0=0, then p0)
#output $a3: bool for if ball hit top/bottom (1 if it did)
  subi $sp,$sp,36
  sw $ra,0($sp)			#store return address
  sw $s0,4($sp)
  sw $s1,8($sp)
  sw $s2,12($sp)
  sw $s3,16($sp)
  sw $s4,20($sp)
  sw $s5,24($sp)
  sw $s6,28($sp)
  sw $a0,32($sp)#store bool to stack
  
  add $s2,$0,$0		#no score yet
  add $s6,$0,$0		#bool for if hit wall
  lbu $s0,ballMovement   #x
  lbu $s1,ballMovement+1 #y

  
  lb $t2,ballMovement+2 #x vel
  lb $t3,ballMovement+3 #y vel
  
  lbu $t4,topOfScreenY		#get top of screen y
  addiu $t4,$t4,1
  li $t5,126		#get bottom of play area y
  
  lbu $t6,playerPositions+3	#player 0 x
  lbu $t7,playerPositions+4	#player 1 x
  
  #copy original coords into s4,s5 registers
  move $s4,$s0
  move $s5,$s1
  #calculate new ball position (x and y), store them in s's
  addu $s0,$s0,$t2		#new x
  addu $s1,$s1,$t3		#new y
  
  #check y positions
  bgtu $s1,$t5,bmBallBounceY	#if calculated y >bottom of screen, bounce
  bltu $s1,$t4,bmBallBounceY	#if calculated y <top of play area line, bounce
  bmCheckX:
  #check x positions (players,goals)
  move $t8,$t6	
  addu $t9,$0,$0
  bleu $s0,$t6,bmBallAtEdge     #check if ball will be at or behind player0
  
  move $t8,$t7	
  li $t9,1	
  bgeu $s0,$t7,bmBallAtEdge	#check if ball will be at or behind player1
  
  bmDidntCollideWithPlayer:
  #if here, then ball didnt collide with anything, or collided with top/bottom
  #if thats the case, then we dont want the ball to move if its not supposed to
  #we only want an early collision if its a player collision, so check that
  lw $a0,32($sp)#load bool from stack
  beqz $a0,bmShouldntMove#bool=0, then this was only a collision check
  #else, move the ball

  
  bmDoneCheckingCollisions:
  #first check if we need to play the wall bounce sound if it got skipped
  lw $a0,32($sp)#load bool from stack
  bnez $a0,bmDontPlaySound
  beqz $s6,bmDontPlaySound#check if hit wall
  #if here, then this is a collision check, but the ball bounced on wall & player
  #therefore, we need to play the wall bounce sound
    #play wall bounce sound here
    li $a0, 68 	#pitch
    li $a1, 250	#duration
    li $a2, 87	#inst
    li $a3, 50	#volume
    li $v0, 31
    syscall
  bmDontPlaySound:
    
  #calculate new ball position (x and y) after finding new velocities
  addu $s0,$s4,$t2		#new x
  addu $s1,$s5,$t3		#new y
  
  sb $t2,ballMovement+2
  sb $t3,ballMovement+3 #update velocities
  sb $s0,ballMovement
  sb $s1,ballMovement+1	#store new x and y
  #draw new ball
  move $a0,$s0
  move $a1,$s1
  lw $s0,ballLastColor	#get the last color (dont need $s0 anymore)
  jal StoreColorAtCoord	#store the color to ballLastColor
  li $a2,3			#ball color
  jal GetColor
  jal DrawBall			#draw the ball
  b bmDidntScore
  bmScored:#scored, get the last color as it wasnt gotten yet
  lw $s0,ballLastColor	#get the last color  
  bmDidntScore:	#already got the color
  #erase the old ball
    move $a0,$s4
    move $a1,$s5		#move initial x and y into position arguments
    move $a2,$s0		#get the last color the ball used
    jal DrawBall
    
  move $v0,$s2		#was there a score?
  move $v1,$s3		#player that scored
  move $a3,$s6		#bool for if hit wall
  
  bmShouldntMove:#go here if it was only a collision check
  
  lw $s6,28($sp)
  lw $s4,20($sp)
  lw $s5,24($sp)
  lw $s3,16($sp)
  lw $s2,12($sp)
  lw $s1,8($sp)
  lw $s0,4($sp)
  lw $ra, 0($sp)
  addi $sp, $sp, 36
  jr $ra
  
  ####below are sub procedures for determining ball collisions and ####
  #### deciding what to do based on where and if it collides	   ####
  bmBallBounceY: #sub procedure to handle when the ball needs to bounce
    neg $t3,$t3	#negate y's velocity
    #should probably make handle vel=+/-2 differently, but the player would never notice this unless 
    # the ball speed was stupid low
    lw $a0,32($sp)#load bool from stack
    beqz $a0,bmBallBounceYDontPlaySound#this is a collision check if branch
    #play sound here
    li $a0, 68 	#pitch
    li $a1, 300	#duration
    li $a2, 87	#inst
    li $a3, 50	#volume
    li $v0, 31
    syscall
    bmBallBounceYDontPlaySound:
    #recalculate y (for corner shots)
    addu $s1,$s1,$t3		#new y
  
    li $s6,1	#bool for ball bouncing
    
    b bmCheckX
    
  bmBallAtEdge: #sub procedure to handle if the ball is at/behind a player
    #the paddle's x is in $t8 for the side we're looking at
    lbu $t7,playerPositions+5	#paddle width
    addu $t5,$0,$0		#$t5 is a temp bool for behind first layer (false here)
    beq $t8,$s0,bmBallAtPlayer	#branch if ball will hit the front of the paddle
    addiu $t5,$t5,1		#ball is behind first layer (used for vel collisions past first layer)
    #else, see if it will collide with top or bottom
    beqz $t9,bmBallAtLeft
      #ball at right
      add $t8,$t8,$t7	#want to go forwards to get behind right paddle
      addu $t8,$t8,1
      bleu $s0,$t8,bmBallAtPlayer #if branch, its at paddle
      b bmBallBehindPlayer
    bmBallAtLeft:
    subu $t8,$t8,$t7	#account for width
    subu $t8,$t8,1
    bge $s0,$t8,bmBallAtPlayer #if branch, its at paddle
    #else its behind player
    bmBallBehindPlayer:
    #see if scored
      li $s3,1			#player 1
      bleu $s0,0,bmScore	#hardcoded goal line
      li $s3,0			#player 0
      bgeu $s0,128,bmScore	#hardcoded goal line
      b bmDidntCollideWithPlayer#no score
      bmScore:
        li $s2,1		#bool for scored		
        b bmScored
    
    bmBallAtPlayer:
      #t6, t7, and t8 are free now 
      #t9 is which player
      #$t5 is bool, if 1 then its behind the first layer. so only apply top/bottom y velocities,
      # since ball can only realistically hit the top and bottom
      lbu $t6,playerPositions($t9)	#player 0/1 y pos
      lbu $t7,playerPositions+2		#paddle length
      addu $t8,$t7,$t6			#y pos+paddle length
      subiu $t8,$t8,1
      bltu $s1,$t6,bmCheckForBallCurrentlyInside #less than top, so no bounce
      bgtu $s1,$t8,bmCheckForBallCurrentlyInside #greater than bottom, so no bounce
      
      bmHitPaddle:
      #set proper x velocity
        li $t2,1#player0
        beqz $t9 bmSetXVel1#branch if player 0
          #hit right paddle
          li $t2,-1
      bmSetXVel1:
        #play sound here
        li $a0, 71 	#pitch
        li $a1, 300	#duration
        li $a2, 87	#inst
        li $a3, 50	#volume
        li $v0, 31
        syscall
      #t7= paddle length
      #t5= bool for behind first layer
        srl $t8,$t7,1		#seperate paddle into segments
        subu $t6,$s1,$t6	#t6=ball calculated y - paddle top y (so number will be within 0-length)
         
        beqz $t5,bmCheckFirstPaddleLayer
          #ball behind first layer here, so only work with top and bottom
          ble $t6,$t8,bmSegTop
          b bmSegBot	#if not top then bottom here
        bmCheckFirstPaddleLayer:
 	beq $t6,$t8,bmSegMiddle	
 	beq $t6,$0,bmSegTop
 	beq $t6,$t7,bmSegBot
	ble $t6,$t8,bmSegTopMid	#less than middle
#       ble $t6,$t7,bmSegBotMid	#after checking <=middle, then if its still in range its bottom
        b bmSegBotMid #else this (should handle if something went wrong but idc) 
           #else, error
#          tlt $t7,$t6
#          li $v0,10
#          syscall
        bmSegMiddle:
          li $t3,0	#y velocity  
          b bmDoneCheckingCollisions 
        bmSegTop:
          li $t3,-2	#y velocity
          b bmDoneCheckingCollisions
        bmSegBot:
          li $t3,2	#y velocity
          b bmDoneCheckingCollisions 
        bmSegTopMid:
          li $t3,-1	#y velocity
          b bmDoneCheckingCollisions
        bmSegBotMid:
          li $t3,1	#y velocity 
          b bmDoneCheckingCollisions
      bmCheckForBallCurrentlyInside:
        #check if the ball is CURRENTLY in the paddle
        beqz $t5,bmDidntCollideWithPlayer #ball cant be inside pre first layer
        #s5 is original y
        move $s1,$s5	#check the original y 
        #try again
        bltu $s1,$t6,bmDidntCollideWithPlayer #less than top, so no bounce
        bgtu $s1,$t8,bmDidntCollideWithPlayer #greater than bottom, so no bounce
        #if here, then the ball is inside the paddle, but wont collide with the paddle
        #should handle normally since this can only happen behind layer 1
        li $t0,8
	lw $t0,ColorTable($t0)	#paddle color
	sw $t0,ballLastColor	#store the paddle color as the last color
        b bmHitPaddle
        
#end BallMovement

DrawBall:
#procedure to draw the ball. use odd nums for size (hard coded)
#input: a0 = x coord center
#input: a1 = y coord center
#input: a2 = color hex
######below is unused#####
#was going to make the ball bigger but its not worth the effort
#input: a3 = size of ball
#input: v1 = ball offset
#subu $a0,$a0,$v1
#subu $a1,$a1,$v1
##########################
  subi $sp,$sp,4
  sw $ra,0($sp)	
  jal DrawDot
  #li $a3,1
  #jal DrawBox
  lw $ra, 0($sp)
  addi $sp, $sp, 4
  jr $ra
#end DrawBall

Player0Handling:
#procedure to handle player inputs. 
#input $a0 - key in ascii pressed
#return $v1 - slow or fast (0,1)
#w=up, W=fast up
#s=down, S=fast down
#anything else = neutral
  subi $sp,$sp,8
  sw $ra,0($sp)			#store return address
  sw $s0,4($sp)
  
  lb $t0,lastPressedKey
  bne $a0,$t0,p0hDiffKeyPressed
    #keys same, so just reuse previous values
    lb $a1,lastPressedKey+1	#direction
    lb $s0,lastPressedKey+2	#speed
    b p0hConclusion		#go to end
  p0hDiffKeyPressed:
  li $s0,0   #slow
    li $a1,-1	#move up
    beq $a0,0x77,p0hConclusion	#w
    
    li $a1,1	#move down
    beq $a0,0x73,p0hConclusion	#s
    
  li $s0,1   #fast
    li $a1,-1	#move up
    beq $a0,0x57,p0hConclusion	#W
    
    li $a1,1	#move down
    beq $a0,0x53,p0hConclusion	#S
  #else, neutral
  li $a1,0	#dont move
  
  p0hConclusion:
    sb $a0,lastPressedKey	#store the last pressed key
    sb $a1,lastPressedKey+1	#store the last direction
    sb $s0,lastPressedKey+2	#store the last speed
    beqz $a1,p0hNoMovement	#movement is 0, so no need to update
      #there is movement:
      li $a0,0			#player 1
      #direction is already in $a1
      jal UpdatePaddlePostions
  p0hNoMovement:
  move $v1,$s0	#return speed
  
  lw $s0,4($sp)
  lw $ra,0($sp)
  addi $sp, $sp, 8
  jr $ra
#end Player0Handling

Player1AI:
#procedure to handle the ai of player1, ie determines where it should move.
#returns its speed
#input .data player1Ai: movement opportunity (higher=more likely to be faster) max 20
#input: ballMovement+1=ball's y pos
#return $v1 - slow or fast (0,1)
  subi $sp,$sp,8
  sw $ra,0($sp)			#store return address
  
  lbu $t4,player1Ai+1	#player 1 chance of messing up
  lbu $t3,playerPositions+2	#player length
  lbu $t0,ballMovement+1	#get ball's y position
  lbu $t1,player1Ai		#get ai movement opportunity
  lbu $t2,playerPositions+1	#player 1 y 

  srl $t3,$t3,1			#length/2
  addu $t2,$t2,$t3		#get p1 middle center
  
  li $v0,30
  syscall		#get time in $a0
  move $t9,$a0
  #determine if ai is fast or slow
  #get rand num 0<x<20, if <$t1, then faster
    li $v0,42	#syscall for rand num
    li $a1,20	#upper bound
    syscall
    addu $v1,$0,$0	#0 for slow
    bgeu $a0,$t1,p1aRolledSlow
      addiu $v1,$v1,1	#$v1=1 for fast movement
  p1aRolledSlow:
    sw $v1,4($sp)	#store speed to stack
    
  #check if ai messed up (if so then no movement)
  #get rand num 0<x<100, if <$t4, then neg movement bit
    move $a0,$t9	#put time back in $a0
    li $v0,42	#syscall for rand num
    li $a1,100	#upper bound
    syscall
    bgeu $a0,$t4,p1aRollDidntMessUp
      addu $a1,$0,$0	#no movement
      b p1aDontMove #dont need to calculate paddle movement
  p1aRollDidntMessUp:
  
  #calculate where to move the paddle:
    #$t2=p1 center coord
    #t0=ball pos
    sub $t2,$t2,$t0
    li $a1,-1		#move up
    bgtz $t2,p1aMove
    li $a1,1		#move down
    bltz $t2,p1aMove
    #else, equal
    b p1aDontMove
  p1aMove:  
  #$a1 = direction
#4 commented out lines is to make p0 also ai
#  move $k1,$a1	#################################################
  li $a0,1		#player 1
  jal UpdatePaddlePostions #update p1's position
  ####################################test code to make both players ai, obv has bugs
#  li $a0,0		#player 1
#  move $a1,$k1
#  jal UpdatePaddlePostions #update p1's position
  ##############################3
  p1aDontMove:
  lw $v1,4($sp)		#get the slow/fast return
  lw $ra,0($sp)
  addi $sp, $sp, 8
  jr $ra
#end Player1Ai

UpdatePaddlePostions:
#procedure to move the player paddles.
#input $a0 - which player (0,1)
#input $a1 - how much to move, 1 or -1. 0 for initial draw
#uses playerPositions for pos data
  subi $sp,$sp,20
  sw $ra,0($sp)			#store return address
  sw $s0,4($sp)
  sw $s1,8($sp)
  sw $s2,12($sp)
  
  lbu $s0,playerPositions($a0)	#current y
  addiu $s1,$a0,3		#which x
  lbu $s1,playerPositions($s1)	#x position
  lbu $t1,topOfScreenY		#get top of screen y
  move $t0,$s0			#move old y into $t0
  addu $s0,$s0,$a1		#get new y
  #end if out of bounds
  bleu $s0,$t1,uppEnd	#if $s0<=$t1 (top of play area)
  lbu $a3,playerPositions+2	#length
  move $t2,$a3
  addu $t2,$t2,$s0		#$t2=pos of bottom y
  bgtu $t2,127,uppEnd	#if $t2>127 (bottom screen) (length needs to be subbed by 1, so add 1 to screen size)
  
  ##
  #s0=new y
  #$s1=x
  #$t1=top of play area
  #$t0=old y
  #a3=length
  #$t2=bottom y pos
  #a0 which player
  
  sb $s0,playerPositions($a0)	#store new position
  
  #get proper x and horiz line length
  lbu $a3,playerPositions+5	#width

  bnez $a0,uppPlayer1
    #player 0, so need to change x
    subu $s1,$s1,$a3		#move x back accordingly
  uppPlayer1:
  beqz $a1,uppFirstTimeDraw	#if 0 movement, then assume first time draw 
  addiu $a3,$a3,1		#length of horiz line
  move $s2,$a3		#store length
  
    #$s0=y top
    #16($sp)=y bottom
  #handle moving up/down:
  bne $a1,1,uppMoveUp
   #moving down
    sw $t0,16($sp) 		#16($sp)=old top
    addiu $s0,$t2,-1		#$t2=old bottom y
    b uppHandledYs
  uppMoveUp:
    #$s0=$s0=new top: already done
    sw $t2,16($sp)		#16($sp)= new bottom
  
  uppHandledYs:  
  li $t0,2
  tge $a1,$t0
  li $t0,-1
  tlt $a1,$t0	#a1 needs to be -1<=a1<=1
  
  #set up for drawing new part
  li $t0,8
  lw $a2,ColorTable($t0)	#paddle color
  #s0 should already be the line to draw
  uppStartErasingHere:	#same for both drawing and erasing past this point
  move $a0,$s1			#x pos
  li $v0,0			#no gap
  li $v1,0			#horiz line
  move $a1,$s0			#y pos  
  move $a3,$s2		#get length 
  jal DrawDottedLine		#erase/draw  
  #do erasing stuff here
    lw $t0,16($sp)		#get y of line to erase
    beq $s0,$t0,uppEnd
    #different, so havent erased yet
    move $s0,$t0
    lw $a2,ColorTable		#background
    b uppStartErasingHere
  
  
  uppFirstTimeDraw:		#draw a fresh player
  move $s2,$a3			#store length
  li $t0,8
  lw $a2,ColorTable($t0)	#paddle color
  uppFirstTimeDrawLoop:
  move $a1,$s0			#y pos

    move $a0,$s1		#x pos
    addu $a0,$a0,$s2		#which x
    li $v0,0			#no gap
    li $v1,1			#vert line
    lbu $a3,playerPositions+2	#length
  jal DrawDottedLine		#draw new player line
  
  subiu $s2,$s2,1		#decrement counter
  bgez $s2,uppFirstTimeDrawLoop	#go until $s2<0 (from above decrement)
  
  
  uppEnd:
  lw $s2,12($sp)
  lw $s1,8($sp)
  lw $s0,4($sp)
  lw $ra,0($sp)
  addi $sp, $sp, 20
  jr $ra
#end UpdatePaddlePostions

PlayerScored:
#procedure to handle player scoring
#input - $a0 player that scored
  subi $sp,$sp,4
  sw $ra,0($sp)	
  sll $a0,$a0,2		#mult it by 4 cause word
  lw $a1,scores($a0)	#get current score
  addiu $a1,$a1,1	#add 1
  sw $a1,scores($a0)	#store new score
  srl $a0,$a0,2		#div it by 4 cause need 0 or 1
  jal DrawScore		#draw the score  
  
  #play sound here
li $a0, 60 	#pitch	#59
li $a1, 1000	#duration
li $a2, 16	#inst
li $a3, 60	#volume
    li $v0, 31
    syscall
  
  lw $ra, 0($sp)
  addi $sp, $sp, 4
  jr $ra
#end PlayerScored

StartRound:
#procedure to handle starting a round (where to put ball)
#commented out code is to spawn the ball at a specific x cord & velocity, and incrament the y coord
  subi $sp,$sp,4
  sw $ra,0($sp)			#store return address
  
 #y coordinate
  li $v0,30
  syscall 			#get time($a0,$a1)
  li $v0,41			#random int ($a0)
  syscall
  lb $t1,topOfScreenY
  addiu $t1,$t1,2		#add 2 to stay in range and not have issues
  li $t2,126			#bottom of screen
  subu $t2,$t2,$t1		#get play space height in $t2
  remu $a1,$a0,$t2
  addu $a1,$a1,$t1		#add unused space to range
  
  
#    lbu $a1,tempthingy#######################
#    addiu $a1,$a1,1#######################
#    sb $a1,tempthingy#######################
  
  sb $a1,ballMovement+1		#set ball's initial y coordinate
  #also put the y coord in $a1
  
  #x coordinate
  li $a0,63			#center
#  li $a0,100			###########################
  sb $a0,ballMovement
  #get the color at the initial coordinate
  jal StoreColorAtCoord	#store the color to ballLastColor
  
  #keep x velocity same after each goal
#    li $t0,1##############################
#    sb $t0,ballMovement+2 #########################

  #y velocity
  li $v0,30
  syscall 			#get time($a0,$a1)
  li $v0,41			#random int ($a0)
  syscall
  remu $t0,$a0,2		#0 or 1
  beq $t0,1,srRandIs1
    li $t0,-1			#if $t0=/=1, then we want -1
  srRandIs1:
#    li $t0,-1	####################################
  sb $t0,ballMovement+3		#y velocity random  -1 or 1
  
  lw $ra, 0($sp)
  addi $sp, $sp, 4
  jr $ra
#end StartRound


UserInputParameters:
#procedure to get the game parameters
#can enter custom params, or use preselected parameters
  subi $sp,$sp,12
  sw $ra,0($sp)			#store return address
  sw $s0,4($sp)
  sw $s1,8($sp)
  
  la $a0,msgEnterDifficulty
  li $v0,4	#print string
  syscall
  jal PrintToKeyBoardMMIO #print to mmio
  jal GetNumsFromKeyboardSim	#get int
  srl $t0,$v0,2
  beqz $t0,uipDifficulty #if 0, then $v0=0-3
  #else, custom
  uipCustom:
  #get ball delays
    la $a0,msgEnterParams0
    li $v0,4	#print string
    syscall	#print prompt
    jal PrintToKeyBoardMMIO #print to mmio
    jal GetNumsFromKeyboardSim	#get initial ball delay
    bgt $v0,40,uipCustom	#initial>40, try again
    blez $v0,uipCustom		#initial<1, try again
    move $s0,$v0		#move initial to s1
    #get min delay:
    la $a0,msgEnterParams1
    li $v0,4	#print string
    syscall	#print prompt
    jal PrintToKeyBoardMMIO #print to mmio
    jal GetNumsFromKeyboardSim	#get min delay
    move $s1,$v0		#move min delay to s1
    blt $s0,$v0,uipCustom	#initial<min, try again
    bgt $v0,40,uipCustom	#min>40, try again
    blez $v0,uipCustom		#min<1, try again
    sb $s0,ballMovement+4
    sb $s1,ballMovement+5
    
  #get cpu ai level
  uipCustomAiLvl:
    la $a0,msgEnterParams2
    li $v0,4	#print string
    syscall	#print prompt
    jal PrintToKeyBoardMMIO #print to mmio
    jal GetNumsFromKeyboardSim	#get cpu ai level
    bltz $v0,uipCustomAiLvl
    bgtu $v0,20,uipCustomAiLvl#check a1 level 0-20
    sb $v0,player1Ai
    
  #get cpu chance to not move  
  uipCustomAiChance:
    la $a0,msgEnterParams3
    li $v0,4	#print string
    syscall	#print prompt
    jal PrintToKeyBoardMMIO #print to mmio
    jal GetNumsFromKeyboardSim	#get cpu chance not to move
    bltz $v0,uipCustomAiChance
    bgtu $v0,100,uipCustomAiChance    #make sure 0-100
    sb $v0,player1Ai+1
    
  #get paddle height
  uipCustomPaddleHeight:
    la $a0,msgEnterParams4
    li $v0,4	#print string
    syscall	#print prompt
    jal PrintToKeyBoardMMIO #print to mmio
    jal GetNumsFromKeyboardSim	#get paddle height
    #make sure its within range, odd
    andi $t0,$v0,0x01#mask out all bits except lsb
    beqz $t0,uipCustomPaddleHeight	#not odd num
    blt $v0,3,uipCustomPaddleHeight
    bgtu $v0,89,uipCustomPaddleHeight    #make sure 3-89 (89 is hard coded, change if topOfScreenY is changed)
    
    sb $v0,playerPositions+2
    move $t4,$v0	#for calculating where to set y coords
    b uipDone	#got all params
    
  uipDifficulty:
  #v0=which difficulty
  #since table, just get position and then cycle thru it
    mul $v0,$v0,5	#5 parameters per entry on table
    la $t5,difficultyTable($v0)
    lbu $s0,($t5)	#initial delay
    lbu $s1,1($t5)	#min delay
    lbu $t2,2($t5)	#ai level
    lbu $t3,3($t5)	#delay chance
    lbu $t4,4($t5)	#paddle lenght
    sb $s0,ballMovement+4
    sb $s1,ballMovement+5
    sb $t2,player1Ai
    sb $t3,player1Ai+1
    sb $t4,playerPositions+2
    #done
    
  uipDone:
  #change y height for players accordingly based on paddle length 
  lb $t0,topOfScreenY
  #t4=pheight
  #ycoord=(127-37/2)+37-(pheight/2)=(127+37-pheight+1)/2
  # =(128+$t0-$t4)/2 (128 cause rounding)
  addiu $t0,$t0,128
  subu $t0,$t0,$t4
  srl $t0,$t0,1
  sb $t0,playerPositions
  sb $t0,playerPositions+1
  
  #get ball dampener parameters set up
  #$s0 = current delay
  #$s1 = min delay
  li $t0,40	#max delay
  li $t3,7 	#get the bit positioner (default 7)
  subu $t0,$t0,$s0	#get offset from 40(max)
  div $t1,$t0,8	#get how many bytes to move ahead
  rem $t2,$t0,8	#get how many bits to move ahead
  subu $t3,$t3,$t2#adjust initial bit positioner
  sb $t1,DampenerPos #set initial position
  sb $t3,DampenerPos+1 #set the initial bit positioner
  sb $t1,DampenerPos+2#set round static
  sb $t3,DampenerPos+3#set round static
 
  #p&r for scoreToWin here (enter 0 for infinite)
  uipEnterScore:#label for neg scores (redundant)
  li $v0,4
  la $a0,msgEnterMaxScore
  syscall
  jal PrintToKeyBoardMMIO #print to mmio
  jal GetNumsFromKeyboardSim	#get score
  bltz $v0,uipEnterScore#redundant
  sw $v0,scoreToWin
  
  la $a0,controlsPrompt
  li $v0,4
  syscall
  jal PrintToKeyBoardMMIO #print to mmio
  
  lw $s1,8($sp)
  lw $s0,4($sp)
  lw $ra, 0($sp)
  addi $sp, $sp, 12
  jr $ra  
#end UserInputParameters

################
#drawing stuff/ misc procedures below
################

DrawGraphicsInitial:
#procedure to generate the initial graphics.
  subi $sp,$sp,36
  sw $ra,0($sp)			#store return address
  sw $s0,4($sp)
  sw $s1,8($sp)
  sw $s2,12($sp)
  sw $s3,16($sp)
  sw $s4,20($sp)
  sw $s5,24($sp)
  sw $s6,28($sp)
  sw $s7,32($sp)
  
  #clear display:
  li $a0,0			#x pos vert line
  li $a1,0			#y pos vert lines
  li $a2,0			#color black
  li $a3,128			#size
  jal DrawBox			#clear the screen
  li $a0,0
  
  li $a2, 1  # White color
  jal GetColor
  #top of play area line
      li $a0, 0		#starting x
      lbu $a1, topOfScreenY
      li $a3,128
      li $v0,0
      li $v1,0			#horiz line
      jal DrawDottedLine
      
  #bottom of play area line
      li $a0, 0		#starting x
      li $a1,127
      li $a3,128
      li $v0,0
      li $v1,0			#horiz line
      jal DrawDottedLine
      
  #draw initial numbers (assuming scores are 0, of course)
  li $a0,0
  li $a1,0
  jal DrawScore
  li $a0,1
  li $a1,0
  jal DrawScore
  #draw initial paddles
  
  #check paddle length
  lbu $t0,playerPositions+2	#paddle length
  li $t1,3
  tlt $t0,$t1			#error if length<3
  subiu $t0,$t0,1		#odd-1=even
  rem $t1,$t0,2		
  tne $t1,$0 			#error here if remainder isnt 0
  
  #draw initial paddles
  add $a0,$0,$0		#player 0
  add $a1,$0,$0 	#no movement
  jal UpdatePaddlePostions
  li $a0,1		#player 1
  add $a1,$0,$0 
  jal UpdatePaddlePostions

#draw middle dotted line with 3 dots per segment and 3 dots per gap, width 3
  li $s0,3			#segment width
  li $s1,3			#gap size
  li $s2,3			#width
  li $s3,63			#starting x
  move $s4,$s0			#segment width but static
  li $t0,16
  lw $a2,ColorTable($t0)	#middle line color
  lbu $s5, topOfScreenY
  addiu $s5,$s5,2
  li $s6,1	#vert
  li $s7,127	#length
  dgiDraw2ndDottedLine:
  addu $s1,$s1,$s0		#include segment width in gap width
  #for i=$s2;i>0;i--		#$s2=line width, $s3=starting x, $s4=vert/horiz
  dgiFor1:
  subiu $s2,$s2,1		#decrement counter
  move $s0,$s4			#reset counter for For2
    #for j=$s0;j>0;j--		#$s0= seg width, $s1=gap size
    dgiFor2:
      subiu $s0,$s0,1
      move $a0, $s3		#starting x
      
      addu $a1,$s0,$s5		#move y down by counter (start at y=top-2)
      move $a3,$s7
      subu $a3,$a3,$s5
      subu $a3,$a3,$s0		#adjust length by counter
      move $v0,$s1		#gap length
      move $v1,$s6		#vert/horiz lines
      jal DrawDottedLine
      bgtz $s0,dgiFor2
      #endfor2
    addiu $s3,$s3,1		#move 1 x over
    bgtz $s2,dgiFor1		#stop when width lines have been drawn
    #endfor1
  
  beqz $s6,dgiDrewBothLines	#dumb way of doing this but it works
  #below draws the line after "PONG," slopply implemented but it works  
  li $s0,6			#segment width
  li $s1,1			#gap size
  li $s2,5			#width
  li $s3,47			#starting x
  move $s4,$s0			#segment width but static
  li $t0,20
  lw $a2,ColorTable($t0)	#pong line color
  li $s5,7		#y top
  #gap already taken care of
  li $s6,0	#horiz
  li $s7,86	#length
  b dgiDraw2ndDottedLine
  
  dgiDrewBothLines:
  #draw "PONG ------"
  li $a0,3
  li $a1,4
  li $a2, 5  # pong color
  jal GetColor
  move $v1,$a2	#move pong color
  li $a2,0	#background
  jal GetColor
  la $a3, pong
  jal OutText	#display "PONG"
  
  lw $s7,32($sp)
  lw $s6,28($sp)
  lw $s5,24($sp)
  lw $s2,12($sp)
  lw $s3,16($sp)
  lw $s4,20($sp)
  lw $s1,8($sp)
  lw $s0,4($sp)
  lw $ra, 0($sp)
  addi $sp, $sp, 36
  jr $ra
#end DrawGraphicsInitial

DrawScore:
#procedure to draw player score numbers.
#ASSUMES THE SCORE ONLY INCRAMENTS BY 1 AND STARTS AT 0 (can be changed, look below)
#$a0 - player 0 or 1
#$a1 - new score
  subi $sp,$sp,24
  sw $ra,0($sp)			#store return address
  sw $s0,4($sp)
  sw $s1,8($sp)
  sw $s2,12($sp)
  sw $s3,16($sp)
  sw $s4,20($sp)
  
  tgeiu $a0,2		#trap if player number isnt 1 or 2
  tlt $a0,$0
  
  lbu $s2,Digits		#max digits number
  lbu $a0,Digits+3($a0)	#x offset for p0/p1
  #$s0=counter, $s1=current number
  move $s0,$s2			#start counter at digit size
  b dsLoopInitial		#if score is 0, the first 0 should still be drawn
  dsLoop:
    ##comment out below line to display all digits every time
    bne $s1,0x30,dsLoopDone	#would only need to display the next digit is if current is 0 (should already be displayed)
    blez $a1,dsLoopDone		#if score<=0, then stop
    blez $s0,dsLoopDone		#if max digits, then done (acts like overflow if above)
    addu $a0,$a0,-10		#move x over since 1 more digit
    dsLoopInitial:
    subi $s0,$s0,1		#decrament counter
    remu $s1,$a1,10		#$s1=score % 10
    subu $a1,$a1,$s1		#score-digit (so score=xxxxy-y=xxxx0)
    divu $a1,$a1,10		#score/10 (so xxxx0/10=xxxx)
  
    addiu $s1,$s1,0x30		#convert to hex
    
    subu $t0,$s2,$s0
    subiu $t0,$t0,1
    sb $s1,digitBuffer($s0)	#store digit in hex (back to front)
    b dsLoop 
    dsLoopDone:
  #display new digits
  li $a1,24		#y coord
  lbu $a2,Digits+1	#number color
  jal GetColor		#number color
  move $s1,$a2
  lbu $a2,Digits+2	#background
  jal GetColor		#background
  la $a3,digitBuffer($s0)#digits to redraw
  move $v1,$s1		#number color
  jal OutText		#draw new digits

  lw $s2,12($sp)
  lw $s3,16($sp)
  lw $s4,20($sp)
  lw $s1,8($sp)
  lw $s0,4($sp)
  lw $ra, 0($sp)
  addi $sp, $sp, 24
  jr $ra
#end DrawScore

DrawBox:
#sub procedure to draw a box. calls DrawLine
#a0 = x coord left
#a1 = y coord top
#a2 = color number (0-7) STILL INDEXED
#a3 = size of box (1-128)
  subi $sp,$sp,20
  sw $ra,0($sp)			#store return address
  sw $s2,4($sp)			#store $s2
  jal GetColor			#make $a2 the hex color
  move $s2,$a3			#counter
  DrawBLoop:
    li $v1,0			#hoirz line for DrawLine
    li $v0,0			#no gaps
    sw $a0,8($sp)			
    sw $a1,12($sp)
    sw $a3,16($sp)		#store arguments

    jal DrawDottedLine		#draw the line
    lw $a0,8($sp)			
    lw $a1,12($sp)
    lw $a3,16($sp)		#load arguments
    
    addiu $a1,$a1,1		#incrament y coord
    subiu $s2,$s2,1		#decrement counter
    bne $s2,$0,DrawBLoop	
  
  lw $s2,4($sp)			#load $s2 
  lw $ra,0($sp)			#load return address 
  addi $sp,$sp,20
  jr $ra
#end DrawBox

DrawDottedLine:
#sub procedure to draw a dotted line. calls DrawDot
#a0 = x coord left
#a1 = y coord top
#a2 = color (NOT INDEXED, already in hex)
#a3 = size of line (1-128)
#v0 = gap per dot (0 for full line)
#v1 = 1 for vert line, 0 (or anything) for horiz line
  subi $sp,$sp,8
  sw $ra,0($sp)			#store return address
  sw $s0,4($sp)
  move $s0,$v0			#store dot distance
  addiu $s0,$s0,1		#add 1
  
  beq $v1,1,dlVertLoop		#vert loop if $v1=1
  #horizontal line
  dlHorzLoop:
    jal DrawDot
    addu $a0,$a0,$s0		#incrament x coord $a0
    subu $a3,$a3,$s0		#decrament line left $a3
    bgt $a3,$0,dlHorzLoop
  b DrawLineDone
  #vertical line
  dlVertLoop:
    jal DrawDot
    addu $a1,$a1,$s0		#incrament y coord $a0
    subu $a3,$a3,$s0		#decrament line left $a3
    bgt $a3,$0,dlVertLoop
  DrawLineDone:
  lw $s0,4($sp)
  lw $ra,0($sp)			#load return address
  addi $sp,$sp,8
  jr $ra
#end DrawDottedLine

DrawDot:
#sub procedure to draw a dot.
#keeps a registers the same
#a0 = x coord
#a1 = y coord
#a2 = color (NOT INDEXED, already in hex)
  subi $sp,$sp,12
  sw $ra,0($sp)			#store return address
  sw $a0,4($sp)			
  sw $a1,8($sp)
  
  sll $a0,$a0,2			#$a0=$a0*4
  sll $a1,$a1,2			#$a1=$a1*4
  sll $a1,$a1,7			#$a1=$a1*128
  lw $t0,BaseAddress		#load address
  addu $v0,$t0,$a0
  addu $v0,$v0,$a1		#$v0=base+$a0x4+$a1x128x4
  
  #ignore below    ####################
  #code to test if colors are being overwritten improperly
  #lw $k0,0($v0)
  #beq $k0,0xFFFFFF,testisTTT
  #bne $k0,0x0000FF,testTTT
  #testisTTT:
  #  bne, $a2,0xFFA500,testTTT
  #  nop
  #testTTT:
  ##############################
  sw $a2,0($v0)			#make dot
  
  lw $a0,4($sp)			
  lw $a1,8($sp)
  lw $ra,0($sp)			#load return address
  addi $sp,$sp,12
  jr $ra
#end DrawDot

StoreColorAtCoord:
#sub procedure to store the current hex color at x and y coords
#a0 = x coord 
#a1 = y coord
#BaseAddress = base address
#returns $v1 = color
  sll $t0,$a0,2			#$a0=$a0*4
  sll $t1,$a1,9			#$a1=$a1*128
  lw $t2,BaseAddress		#load address
  addu $v0,$t2,$t0
  addu $v0,$v0,$t1		#$v0=base+$a0x4+$a1x256x4
  lw $t2,0($v0)			#get color
  sw $t2,ballLastColor		#store the color to .data
  jr $ra
#end StoreColorAtCoord

GetColor:
#sub procedure to convert color 1-7 coords into actual color
#a2 = color 0-7
#returns $a2 = color hex
  sll $a2,$a2,2			#offset by 4
  lw $a2,ColorTable($a2)
  jr $ra
#end GetColor

OutText:
# OutText: display ascii characters on the bit mapped display
# $a0 = horizontal pixel co-ordinate (0-127)
# $a1 = vertical pixel co-ordinate (0-127)
# $a2 = background color (hex)
# $a3 = pointer to asciiz text (to be displayed)
# $v1 = number color
        addiu   $sp, $sp, -24
        sw      $ra, 20($sp)

        li      $t8, 1          # line number in the digit array (1-12)
_text1:
	lw $t9,BaseAddress
        la      $t9, ($t9)	 # get the memory start address
        sll     $t0, $a0, 2     # assumes mars was configured as 128 x 128
        addu    $t9, $t9, $t0   # and 1 pixel width, 1 pixel height
        sll     $t0, $a1, 9    # (a0 * 4) + (a1 * 4 * 128)
        addu    $t9, $t9, $t0   # t9 = memory address for this pixel

        move    $t2, $a3        # t2 = pointer to the text string
_text2:
        lb      $t0, 0($t2)     # character to be displayed
        addiu   $t2, $t2, 1     # last character is a null
        beq     $t0, $zero, _text9

        la      $t3, DigitTable # find the character in the table
_text3:
        lb      $t4, 0($t3)     # get an entry from the table
        beq     $t4, $t0, _text4
        beq     $t4, $zero, _text4
        addiu   $t3, $t3, 13    # go to the next entry in the table
        b       _text3
_text4:
        addu    $t3, $t3, $t8   # t8 is the line number
        lb      $t4, 0($t3)     # bit map to be displayed

        sw      $a2, 0($t9)   # first pixel is background
        addiu   $t9, $t9, 4

        li      $t5, 8          # 8 bits to go out
_text5:
        move    $t7, $a2     	#background color
        andi    $t6, $t4, 0x80  # mask out the bit (0=black, 1=white)
        beq     $t6, $zero, _text6
     # else it is num color
        move      $t7, $v1
_text6:
        sw      $t7, 0($t9)     # write the pixel color
        addiu   $t9, $t9, 4     # go to the next memory position
        sll     $t4, $t4, 1     # and line number
        addiu   $t5, $t5, -1    # and decrement down (8,7,...0)
        bne     $t5, $zero, _text5

        sw      $a2, 0($t9)    # last pixel is background
        addiu   $t9, $t9, 4
        b       _text2          # go get another character

_text9:
        addiu   $a1, $a1, 1     # advance to the next line
        addiu   $t8, $t8, 1     # increment the digit array offset (1-12)
        bne     $t8, 13, _text1

        lw      $ra, 20($sp)
        addiu   $sp, $sp, 24
        jr      $ra


GetNumsFromKeyboardSim:
#procedure to collect a number from the keyboard interrupt, terminated by a newline
#return $v0 = the number
# slightly modified from simon says, this is the only thing that
#  uses interrupts for the keyboard input.
#CURRENTLY CANNOT HANDLE NEGATIVE NUMBERS
#its kind of poorly written, but it works so i dont care
  subi $sp,$sp,4
  sw $ra,0($sp)			#store return address
  
  # Enable keyboard interrupts
    li $t0, 0xffff0000		#Receiver control register
    li $t1, 0x00000002		# Interrupt enable bit
    sw $t1, ($t0)
  
  gnfiStart:
  lb $t0, buffer_head
  lb $t1, buffer_tail
  beq $t0, $t1, gnfiStart	#If buffer is empty, keep checking
  
# Read from buffer
  la $t2, keyboard_buffer
  add $t2, $t2, $t0
  lb $t4, ($t2)

  addi $t0, $t0, 1
  sb $t0, buffer_head
  bgtu $t0,10,gnfiTooManyDigits	#more than 10 digits stop polling
  bne $t4,0x0A,gnfiStart	#if enter was pressed, you have number. else loop
  gnfiTooManyDigits:#number is ready
  # Disable interrupts
  mfc0 $t0, $12			# Read from the Status register
  andi $t0, $t0, 0xFFFE		# Clear the least significant bit (interrupt enable)
  mtc0 $t0, $12			# Write back to the Status register
    
  # Convert Buffer to decimal
  lb $t3, buffer_tail
  subiu $t3,$t3,2		#ignore the newline
  move $t1,$t3
  addiu $t1,$t1,1
  la $t0, keyboard_buffer
  li $t8,0
  gnfiLoop:
    subiu $t1,$t1,1		#decrement counter/pointer
    move $t2,$t0
    add $t2,$t2,$t1
    lb $t4,($t2)
    bgtu $t4,0x39,gnfiInvalidNum
    bltu $t4,0x30,gnfiInvalidNum#if t4 not a number, error
    subi $t4,$t4,0x30		#convert to number
    subu $t5,$t3,$t1		#digit multiplier
  
    #do 10^$t5 here, then multiply $t4 with that
    li $t2,10			#Load 10 into $t2 (base)
    li $t7,1			#Initialize result as 1 (10^0)
    move $t6,$t5		#Copy exponent to $t6
    gnfiPowerLoop:
      beqz $t5,gnfiPowerLoopEnd	#If exponent is zero, exit loop
      mulu $t7,$t7,10		#Multiply current result by 10
      subi $t5,$t5,1		#Decrease exponent by 1
      j gnfiPowerLoop		#Repeat the loop
    gnfiPowerLoopEnd:
    mul $t2,$t7,$t4		#Multiply the result (10^$t5) by $t4
    addu $t8,$t2,$t8		#Add to number
    #decrementer is at start of loop
    bnez $t1,gnfiLoop #get all nums in buffer
    
  move $a0,$t8
  li $v0,1
  syscall			#show the number in console
  
  li $v0,11			#Print char syscall
  li $a0,10
  syscall			#print newline
  move $v0,$t8			#put result in $v0
  
  #Enable interrupts
    mfc0 $t0, $12		# Read from the Status register
    ori  $t0, $t0, 0x0001	# Set the least significant bit (interrupt enable)
    mtc0 $t0, $12		# Write back to the Status register
  
  #Disable keyboard interrupts
    li $t0, 0xffff0000		#Receiver control register
    li $t1, 0x00000000		# Interrupt disable bit
    sw $t1, ($t0)
    
  jal clear_buffer		#clear the buffer
  lw $ra, 0($sp)
  addi $sp, $sp, 4
  jr $ra
  
  gnfiInvalidNum:
    la $a0,invalidNum
    li $v0,4
    syscall
    jal PrintToKeyBoardMMIO #print to mmio
    jal clear_buffer		#clear the buffer
    #Enable interrupts
    mfc0 $t0, $12		# Read from the Status register
    ori  $t0, $t0, 0x0001	# Set the least significant bit (interrupt enable)
    mtc0 $t0, $12		# Write back to the Status register
    b gnfiStart	#bad number was given, so just restart from the beginning
#end GetNumsFromInterrupt

PrintToKeyBoardMMIO:
#procedure to print a null terminated string to the keyboard and display mmio sim
#input $a0: address of null terminated string
#doesnt modify registers after call
  subi $sp,$sp,20
  sw $ra,0($sp)			#store return address
  sw $s0,4($sp)
  sw $s1,8($sp)
  sw $s2,12($sp)
  sw $a0,16($sp)
   
  ptkbmmioStart:
  #load the character to display
  lbu $s0, 0($a0)	#load the character byte into $s0
  beqz $s0,ptkbmmioEnd	#null char
  
  #write to the display control register to indicate data is ready
  li $s1, 0xFFFF0008	#display Control Register address
  li $s2, 1		#indicate that data is ready
  sw $s2, 0($s1)	#store the word to the display control register
  #write the character to the display data register
  li $s1, 0xFFFF000C	#display Data Register address
  sb $s0, 0($s1)	#store the byte to the display data register
  addiu $a0,$a0,1	#next char
  b ptkbmmioStart
  ptkbmmioEnd:
  lw $a0,16($sp)
  lw $s2,12($sp)
  lw $s1,8($sp)
  lw $s0,4($sp)
  lw $ra,0($sp)
  addi $sp, $sp, 20
  jr $ra
#end PrintToKeyBoardMMIO

pause:
#sub procedure to pause. will put variables back when done
#$a0: input for amount of time to pause (in miliseconds)
  subi $sp,$sp,20
  sw $t0,0($sp)
  sw $t1,4($sp)
  sw $t2,8($sp)
  sw $v0,12($sp)		 
  sw $a1,16($sp)		#store used variables 
  
  move $t0,$a0			#save pause time to $t0
  li $v0,30
  syscall			#get initial time
  move $t1,$a0			#save time
  pauseLoop:
    syscall			#get current time
    sub $t2,$a0,$t1		#elapsed=current-initial
    bltu $t2,$t0,pauseLoop	#if elapsed<timeout,loop
  
  lw $t0,0($sp)
  lw $t1,4($sp)
  lw $t2,8($sp)
  lw $v0,12($sp)
  lw $a1,16($sp)
  addi $sp,$sp,20		#put used varaibles back
  jr $ra


clear_buffer:
#procedure clears and resets the buffer
  la $t0, keyboard_buffer
  li $t1, 11		#Buffer size
  li $t2, 0		#Counter
  clear_loop:
    sb $zero,($t0)	#Clear byte
    addi $t0,$t0,1	#Move to next byte
    addi $t2,$t2,1	#Increment counter
    bne $t2,$t1,clear_loop
  #Reset head and tail pointers
  sb $zero, buffer_head
  sb $zero, buffer_tail
  jr      $ra
#end clear_buffer


##################################
	########################################################################
	#   Description:
	#       Example SPIM exception handler
	#       Derived from the default exception handler in the SPIM S20
	#       distribution.
	#
	#   History:
	#       Dec 2009    J Bacon
	
	########################################################################
	# Exception handling code.  This must go first!
	
			.kdata
	__start_msg_:   .asciiz "  Exception "
	__end_msg_:     .asciiz " occurred and ignored\n"
	
	# Messages for each of the 5-bit exception codes
	__exc0_msg:     .asciiz "  [Interrupt] "
	__exc1_msg:     .asciiz "  [TLB]"
	__exc2_msg:     .asciiz "  [TLB]"
	__exc3_msg:     .asciiz "  [TLB]"
	__exc4_msg:     .asciiz "  [Address error in inst/data fetch] "
	__exc5_msg:     .asciiz "  [Address error in store] "
	__exc6_msg:     .asciiz "  [Bad instruction address] "
	__exc7_msg:     .asciiz "  [Bad data address] "
	__exc8_msg:     .asciiz "  [Error in syscall] "
	__exc9_msg:     .asciiz "  [Breakpoint] "
	__exc10_msg:    .asciiz "  [Reserved instruction] "
	__exc11_msg:    .asciiz "11"
	__exc12_msg:    .asciiz "  [Arithmetic overflow] "
	__exc13_msg:    .asciiz "  [Trap] "
	__exc14_msg:    .asciiz "14"
	__exc15_msg:    .asciiz "  [Floating point] "
	__exc16_msg:    .asciiz "16"
	__exc17_msg:    .asciiz "17"
	__exc18_msg:    .asciiz "  [Coproc 2]"
	__exc19_msg:    .asciiz "19"
	__exc20_msg:    .asciiz "20"
	__exc21_msg:    .asciiz "21"
	__exc22_msg:    .asciiz "  [MDMX]"
	__exc23_msg:    .asciiz "  [Watch]"
	__exc24_msg:    .asciiz "  [Machine check]"
	__exc25_msg:    .asciiz "25"
	__exc26_msg:    .asciiz "26"
	__exc27_msg:    .asciiz "27"
	__exc28_msg:    .asciiz "28"
	__exc29_msg:    .asciiz "29"
	__exc30_msg:    .asciiz "  [Cache]"
	__exc31_msg:    .asciiz "31"
	
	__level_msg:    .asciiz "Interrupt mask: "
	
	
	#########################################################################
	# Lookup table of exception messages
	__exc_msg_table:
		.word   __exc0_msg, __exc1_msg, __exc2_msg, __exc3_msg, __exc4_msg
		.word   __exc5_msg, __exc6_msg, __exc7_msg, __exc8_msg, __exc9_msg
		.word   __exc10_msg, __exc11_msg, __exc12_msg, __exc13_msg, __exc14_msg
		.word   __exc15_msg, __exc16_msg, __exc17_msg, __exc18_msg, __exc19_msg
		.word   __exc20_msg, __exc21_msg, __exc22_msg, __exc23_msg, __exc24_msg
		.word   __exc25_msg, __exc26_msg, __exc27_msg, __exc28_msg, __exc29_msg
		.word   __exc30_msg, __exc31_msg
	
	# Variables for save/restore of registers used in the handler
	save_v0:    .word   0
	save_a0:    .word   0
	save_at:    .word   0
buffer_head: .byte 0
buffer_tail: .byte 0
keyboard_buffer: .space 11
	#########################################################################
	# This is the exception handler code that the processor runs when
	# an exception occurs. It only prints some information about the
	# exception, but can serve as a model of how to write a handler.
	#
	# Because this code is part of the kernel, it can use $k0 and $k1 without
	# saving and restoring their values.  By convention, they are treated
	# as temporary registers for kernel use.
	#
	# On the MIPS-1 (R2000), the exception handler must be at 0x80000080
	# This address is loaded into the program counter whenever an exception
	# occurs.  For the MIPS32, the address is 0x80000180.
	# Select the appropriate one for the mode in which SPIM is compiled.
	
		.ktext  0x80000180
	
		# Save ALL registers modified in this handler, except $k0 and $k1
		# This includes $t* since the user code does not explicitly
		# call this handler.  $sp cannot be trusted, so saving them to
		# the stack is not an option.  This routine is not reentrant (can't
		# be called again while it is running), so we can save registers
		# to static variables.
  sw $a0, save_a0
  sw $v0, save_v0
	
		# $at is the temporary register reserved for the assembler.
		# It may be modified by pseudo-instructions in this handler.
		# Since an interrupt could have occurred during a pseudo
		# instruction in user code, $at must be restored to ensure
		# that that pseudo instruction completes correctly.
		.set    noat
		sw      $at, save_at
		.set    at
		
    #Check if it's a keyboard interrupt
    mfc0 $k0, $13	#Get Cause register
    andi $k0, $k0, 0x0000FF00
    bnez $k0, keyboard_interrupt
		
		# Determine cause of the exception
		mfc0    $k0, $13        # Get cause register from coprocessor 0
		srl     $a0, $k0, 2     # Extract exception code field (bits 2-6)
		andi    $a0, $a0, 0x1f
		
		# Check for program counter issues (exception 6)
		bne     $a0, 6, ok_pc
		nop
	
		mfc0    $a0, $14        # EPC holds PC at moment exception occurred
		andi    $a0, $a0, 0x3   # Is EPC word-aligned (multiple of 4)?
		beqz    $a0, ok_pc
		nop
	
		# Bail out if PC is unaligned
		# Normally you don't want to do syscalls in an exception handler,
		# but this is MARS and not a real computer
		li      $v0, 4
		la      $a0, __exc3_msg
		syscall
		li      $v0, 10
		syscall
	
	ok_pc:
		mfc0    $k0, $13
		srl     $a0, $k0, 2     # Extract exception code from $k0 again
		andi    $a0, $a0, 0x1f
		bnez    $a0, non_interrupt  # Code 0 means exception was an interrupt
		nop
	
		# External interrupt handler
		# Don't skip instruction at EPC since it has not executed.
		# Interrupts occur BEFORE the instruction at PC executes.
		# Other exceptions occur during the execution of the instruction,
		# hence for those increment the return address to avoid
		# re-executing the instruction that caused the exception.
	
	     # check if we are in here because of a character on the keyboard simulator
		 # go to nochar if some other interrupt happened
		 
		 # get the character from memory
		 # store it to a queue somewhere to be dealt with later by normal code

		j	return
    
keyboard_interrupt:
    lw $v0,0xffff0000	#Check keyboard status
    andi $v0,$v0,0x0001
    beqz $v0,return	#If no key pressed, return

    lw $a0,0xffff0004	#Read the key

    # Store in circular buffer
    la $v0,keyboard_buffer
    lb $k1,buffer_tail
    add $v0,$v0,$k1	# Calculate position in buffer
    sb $a0,($v0)	# Store key in buffer
    addi $k1,$k1,1
    rem $k1,$k1,0x0c	# Wrap around (buffer size 11)
    sb $k1,buffer_tail
    
  #write to the display control register to indicate data is ready
    li $v0, 0xFFFF0008  #display Control Register address
    li $k1, 1           #indicate that data is ready
    sw $k1, 0($v0)      #store the word to the display control register
  #write the character to the display data register
    li $v0, 0xFFFF000C  #display Data Register address
    sb $a0, 0($v0)      #store the byte to the display data register

    
    b return
    
nochar:
		# not a character
		# Print interrupt level
		# Normally you don't want to do syscalls in an exception handler,
		# but this is MARS and not a real computer
		li      $v0, 4          # print_str
		la      $a0, __level_msg
		syscall
		
		li      $v0, 1          # print_int
		mfc0    $k0, $13        # Cause register
		srl     $a0, $k0, 11    # Right-justify interrupt level bits
		syscall
		
		li      $v0, 11         # print_char
		li      $a0, 10         # Line feed
		syscall
		
		b       return
	
	non_interrupt:
		# Print information about exception.
		# Normally you don't want to do syscalls in an exception handler,
		# but this is MARS and not a real computer
		li      $v0, 4          # print_str
		la      $a0, __start_msg_
		syscall
	
		li      $v0, 1          # print_int
		mfc0    $k0, $13        # Extract exception code again
		srl     $a0, $k0, 2
		andi    $a0, $a0, 0x1f
		syscall
	
		# Print message corresponding to exception code
		# Exception code is already shifted 2 bits from the far right
		# of the cause register, so it conveniently extracts out as
		# a multiple of 4, which is perfect for an array of 4-byte
		# string addresses.
		# Normally you don't want to do syscalls in an exception handler,
		# but this is MARS and not a real computer
		li      $v0, 4          # print_str
		mfc0    $k0, $13        # Extract exception code without shifting
		andi    $a0, $k0, 0x7c
		lw      $a0, __exc_msg_table($a0)
		nop
		syscall
	
		li      $v0, 4          # print_str
		la      $a0, __end_msg_
		syscall
	
		# Return from (non-interrupt) exception. Skip offending instruction
		# at EPC to avoid infinite loop.
		mfc0    $k0, $14
		addiu   $k0, $k0, 4
		mtc0    $k0, $14
	
	return:
		# Restore registers and reset processor state
  lw $a0, save_a0
  lw $v0, save_v0
	
		.set    noat            # Prevent assembler from modifying $at
		lw      $at, save_at
		.set    at
	
		mtc0    $zero, $13      # Clear Cause register
	
		# Re-enable interrupts, which were automatically disabled
		# when the exception occurred, using read-modify-write cycle.
		mfc0    $k0, $12        # Read status register
		andi    $k0, 0xfffd     # Clear exception level bit
		ori     $k0, 0x0001     # Set interrupt enable bit
		mtc0    $k0, $12        # Write back
	
		# Return from exception on MIPS32:
		eret
