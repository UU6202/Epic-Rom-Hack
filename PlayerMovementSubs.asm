GPTmr = $07a3
GPLandTmr = $07a3	;share, since they do not happen at the same time
Player_Y_Speed_Exag = $54
Multiple_Jump_Ctr = $07e3
Multiple_Jump_Tmr = $07a5
WaterFriction = $0040

PlayerMovementSubs:
	ldy #$01
	lda Player_X_Speed,x
	bne @NotZeroSpeed
	lda MyJoypadHeld,x
	and #Left_Dir|Right_Dir
	tay
	beq @ZeroAndNeutral
	lda #$00
	bpl @SetSpeedAndDir
@ZeroAndNeutral:
	lda #$01
	iny
@NotZeroSpeed:
	bpl @SetSpeedAndDir	;bra for zero and neutral
	eor #$ff
	clc
	adc #$01
	iny
@SetSpeedAndDir:
	sta Player_XSpeedAbsolute
	sty Player_MovingDir,x
	lda Player_Y_Speed,x
	sta Player_Y_Speed_Exag,x
	lda Player_Y_MoveForce,x
	asl
	rol Player_Y_Speed_Exag,x
	asl
	rol Player_Y_Speed_Exag,x
	asl
	rol Player_Y_Speed_Exag,x
	asl
	rol Player_Y_Speed_Exag,x
	
	lda #>(AccelByData-1)	;rts -> jmp AccelByData
	pha
	lda #<(AccelByData-1)
	pha
	
	lda Player_State,x
	jsr JumpEngine
	.word StateSubNormal	;on ground/running/skidding
	.word StateSubJumping
	.word StateSubFalling
	.word StateSubClimbing
	.word StateSubSwimming
	.word StateSubFloating
	.word StateSubBackflip
	.word StateSubLJ
	.word StateSubGPReady
	.word StateSubGP
	.word StateSubGPLand
	.word StateSubGPJump
	.word StateSubUnderwaterGP
	.word StateSubUnderwaterGPFade
	.word StateSubUnderwaterGPLand
	.word StateSubDive
	.word StateSubUnderwaterDive
	.word StateSubWallSlide
	
StateNormal = 0
StateJumping = 1
StateFalling = 2
StateClimbing = 3
StateSwimming = 4
StateFloating = 5
StateBackflip = 6
StateLJ = 7
StateGPReady = 8
StateGP = 9
StateGPLand = 10
StateGPJump = 11
StateUnderwaterGP = 12
StateUnderwaterGPFade = 13
StateUnderwaterGPLand = 14
StateDive = 15
StateUnderwaterDive = 16
StateWallSlide = 17

StateSubNormal:
	;todo jsr check tile above player
	lda MyJoypadHeld,x
	and #Down_Dir
	beq @Uncrouch
	inc CrouchingFlag,x	;now as a counter instead of always holding %00000100
	bne @UncrouchEnd	;bra
	lda #$ff	;except overflowed! $00->$ff
@Uncrouch:
	sta CrouchingFlag,x
@UncrouchEnd:
	
	lda MyJoypadPressed,x
	and #A_Button
	beq @NotJump
	lda CrouchingFlag,x	;A button pressed
	beq @NotCrouch
	lda Player_XSpeedAbsolute	;is crouch => either backflip, crouch jump or long jump
	cmp #$24	;lj speed threshold
	bmi @NotLJ
	lda #StateLJ	;is lj
	sta Player_State,x	;update state
	jmp NewStateY
	
@NotLJ:
	bne @NotBackflip	;speed must be 0
	lda CrouchingFlag,x	;and crouching for >48 frames
	cmp #$30			;to backflip
	bcc @NotBackflip	;bcc -> siged cmp
	lda #StateBackflip	;is backflip
	sta Player_State,x	;update state
	jsr NewStateX
	jmp NewStateY
	
@NotCrouch:
	dec Multiple_Jump_Tmr,x	;not crouch => triple jump
	beq @FailTriple
	inc Multiple_Jump_Ctr,x
	bpl @SetJump	;bra
@NotBackflip:	;is crouch jump => reset multiple jump ctr
@FailTriple:	;reset multiple jump ctr
	lda #$00
	sta Multiple_Jump_Ctr,x
@SetJump:
	lda #StateJumping
	sta Player_State,x	;update state
	jsr NewStateY
	jmp NewStateYFromX
	
@NotJump:
	lda MyJoypadHeld,x	;only change dir on ground
	and #Left_Dir|Right_Dir
	beq @Neutral
	sta PlayerFacingDir,x
@Neutral:
	rts
	
ChkGP:
	lda MyJoypadPressed,x
	and #Down_Dir
	beq @NotGP
	pla	;not going back!
	pla
	lda #$10
	sta GPTmr,x
	lda #StateGPReady	;ready to GP!
	sta Player_State,x	;update state
	jsr NewStateShiftX
	jmp NewStateY
@NotGP:
	rts
	
StateSubJumping:
StateSubBackflip:
StateSubGPJump:
	jsr ChkGP
	
	lda Player_Y_Speed_Exag,x
	bmi @NotFalling
	lda #StateFalling	;Y speed >= 0 => falling
	sta Player_State,x
@NotFalling:
	rts
	
StateSubFalling:
StateSubFloating:
	jsr ChkGP
	;todo
	;ldy #StateFalling
	;lda PlayerStatus,x
	;cmp #FloatingPowerupStatusID
	;bne @NotFloat
	;lda MyJoypadHeld,x
	;and #A_Button
	;beq @NotFloat
	;ldy #StateFloating
;@NotFloat:
	;sty Player_State,x
	rts
	
StateSubClimbing:
	pla
	pla
	jmp ClimbingSub
StateSubSwimming:
	jsr ChkGP
	lda MyJoypadPressed,x
	and #A_Button
	beq @NotSwimInit
	jmp NewStateY
@NotSwimInit:
	rts
	
StateSubLJ:
StateSubDive:
	rts	;cannot transit to another state. maybe bonk?
	
ChkDive:
	lda MyJoypadPressed,x
	and #B_Button
	beq @NotDive
	lda MyJoypadHeld,x
	and #Down_Dir
	beq @NotDive
	
	lda PlayerFacingDir,x	;dive in facing dir!
	sta Player_MovingDir,x
	
	lda AreaType	;todo: check state/tile instead of area type
	beq @Underwater	;0 -> underwater
	lda #StateDive
	bne @SetState
@Underwater:
	lda #StateUnderwaterDive
@SetState:
	sta Player_State,x
	jmp NewStateX
@NotDive:
	rts
	
StateSubGPReady:
	lda MyJoypadHeld,x
	beq @Neutral
	sta PlayerFacingDir,x
@Neutral:
	jsr ChkDive
	;no cancel during ready
	dec GPTmr,x
	bne @Skip
	;GP!
	lda AreaType	;todo: check state/tile instead of area type
	beq @Underwater	;0 -> underwater
	lda #StateGP
	bne @SetState
@Underwater:
	lda #StateUnderwaterGP
@SetState:
	sta Player_State,x
	jmp NewStateY
@Skip:
	rts
	
StateSubGP:
	jsr ChkDive
	lda MyJoypadHeld,x	;held up?
	and #Up_Dir
	beq @NoCancel
	lda #StateFalling	;GP cancel
	sta Player_State,x
@NoCancel:
	rts
	
StateSubGPLand:
	lda MyJoypadPressed,x
	and #A_Button
	beq @NotJump
	lda #StateGPJump
	sta Player_State,x
	jmp NewStateY
@NotJump:
	dec GPLandTmr,x
	bne @NotExitGPLand
	lda #StateNormal
	sta Player_State,x
@NotExitGPLand:
	rts
	
StateSubUnderwaterGP:
	jsr ChkDive
	lda MyJoypadHeld,x
	and #Down_Dir
	bne @NotFade
	lda #StateUnderwaterGPFade	;released down
	sta Player_State,x
	;inc Player_State,x
@NotFade:
	rts
	
StateSubUnderwaterGPFade:
	ldy Player_Y_Speed_Exag
	dey
	bne @NotExitUGPFade
	lda #StateSwimming
	sta Player_State,x
@NotExitUGPFade:
	rts
	
StateSubUnderwaterGPLand:
	lda GPLandTmr,x
	bne @NotExitUGPFade
	lda #StateSwimming
	sta Player_State,x
@NotExitUGPFade:
	rts
	
StateSubUnderwaterDive:
	lda Player_XSpeedAbsolute
	cmp SoftCapXData+StateUnderwaterDive
	bcs @NotCancel
	lda #StateSwimming
	sta Player_State,x
	jmp StateSubSwimming
@NotCancel:
	rts
	
StateSubWallSlide:
	lda MyJoypadPressed,x
	pha
	and #A_Button
	beq @NotWJ
	;wall jump
	
@NotWJ:
	pla
	and #Down_Dir
	beq @NotCancel
	lda #StateFalling
	sta Player_State,x
@NotCancel:
	rts

NewStateShiftX:
	lsr Player_XSpeedAbsolute
	lsr Player_XSpeedAbsolute
	rts
	
NewStateX:
	ldy Player_State,x
	lda SetXData,y
	sta Player_XSpeedAbsolute
	rts
	
NewStateYFromX:	;adds X speed / 4 to initial Y speed as bonus
	lda Player_XSpeedAbsolute
	lsr	;/4
	lsr
	sta $00
	lda Multiple_Jump_Ctr,x
	asl	;*4
	asl	;and clc
	adc $00	;double jump => +4, triple jump => +8 (can reach 6+3/16 blocks high with 40 x speed)
	eor #$ff	;neg (negative is upwards)
	sec	;the ++ here
	adc Player_Y_Speed_Exag,x	;+ Y speed
	sta Player_Y_Speed_Exag,x
	rts
	
NewStateY:
	ldy Player_State,x
	lda SetYData,y
	sta Player_Y_Speed_Exag,x
	rts
	
AccelByData:
	clv ;bvc->bra
	ldy Player_State,x
	lda MyJoypadHeld,x
	and #Left_Dir|Right_Dir
	eor Player_MovingDir,x	;0 -> same -> accel, 3 -> oppo -> decel, 1 or 2 -> neutral
	bne @NotAccel 
	lda Player_XSpeedAbsolute
	cmp SoftCapXData,y	;exceed soft cap?
	bpl @IsNeutral	;yes, use neutral instead (unaffect in air, slow down on ground)
	lda AccelXData,y	;otherwise accel as normal
	bvc @ApplyAccel
@NotAccel:
	cmp #$03
	beq @IsDecel
@IsNeutral:
	lda NeutralXData,y	;
	bvc @ApplyAccel
@IsDecel:
	lda DecelXData,y	;

@ApplyAccel:
	ldy AreaType
	bne @NotWater	;ground => skip the following
	clc
	pha	;accel data to be added
	lda Player_X_MoveForce,x
	ldy Player_MovingDir,x
	dey
	beq @MovingRight
	
	;clc
	adc #<(WaterFriction)
	pla
	bcs @clr
	sec
	bcs @set
@clr:
	clc
@set:
	adc #>(WaterFriction)
	jmp @NotWater

@MovingRight:
	;clc
	adc #<(-WaterFriction)
	sta Player_X_MoveForce,x
	pla
	adc #>(-WaterFriction)

@NotWater:
	ldy Player_State,x
	clc	;speed += accel
	adc Player_XSpeedAbsolute
	cmp HardCapXData,y	;min(x speed, x hard cap)
	bmi @NotExceed
	lda HardCapXData,y
@NotExceed:
	cmp MinCapXData,y
	bpl @NotUnder
	lda MinCapXData,y
@NotUnder:
	;sta Player_XSpeedAbsolute
	pha
	lda Player_MovingDir,x
	cmp #$01
	beq @NoInvert
	pla
	eor #$ff
	adc #$00	;carry always set
	pha
@NoInvert:
	pla
	sta Player_X_Speed,x

	lda Player_Y_Speed_Exag,x
	cmp SoftCapYData,y ;exceed soft cap?
	bpl @IsSoftexceed ;yes, don't accel
	pha 
	lda Player_Y_MoveForce,x
	clc
	adc AccelYSubData,y
	sta Player_Y_MoveForce,x
	pla
	adc AccelYData,y
@IsSoftexceed:
	cmp HardCapYData,y	;min(y speed, y hard cap)
	bmi @NotHardexceed
	lda #$00
	sta Player_Y_MoveForce,x
	lda HardCapYData,y
@NotHardexceed:

	sta Player_Y_Speed_Exag,x	;debugging purposes
	lsr
	ror Player_Y_MoveForce,x
	lsr
	ror Player_Y_MoveForce,x
	lsr
	ror Player_Y_MoveForce,x
	lsr
	ror Player_Y_MoveForce,x
	cmp #$08
	bmi @Positive
	ora #$f0
@Positive:
	sta Player_Y_Speed,x
	
	jsr MovePlayerHorizontally
	sta Player_X_Scroll
	lda #$05
	sta $02
	lda #$00
	sta $00
	jmp ImposeGravity
	
LSRs:
	bit $00
	beq lsr0
	dec $00
	beq lsr1
	dec $00
	beq lsr2
	dec $00
	beq lsr3
	dec $00
	beq lsr4
	dec $00
	beq lsr5
	dec $00
	beq lsr6
	dec $00
	beq lsr7
	lsr
lsr7:
	lsr
lsr6:
	lsr
lsr5:
	lsr
lsr4:
	lsr
lsr3:
	lsr
lsr2:
	lsr
lsr1:
	lsr
lsr0:
	rts

vvv = $80	;dummy extreme value for debugging

;CarryXData:
	;.byte vvv, vvv, vvv, vvv, vvv, vvv, vvv, vvv, $02, vvv, vvv, vvv, vvv, vvv, vvv, vvv, vvv
SetXData:
	.byte vvv, vvv, vvv, vvv, vvv, vvv, 8, vvv, vvv, vvv, vvv, vvv, vvv, vvv, vvv, 32, 48
AccelXData:
	.byte 1, 1, 1, vvv, 1, 1, 2, 2, 0, 1, 0, 1, 0, 1, 0, 2, 0
NeutralXData:
	.byte 256-1, 0, 0, vvv, 0, 0, 1, 0, 256-3, 256-1, 0, 0, 0, 0, 0, 2, 0
DecelXData:
	.byte 256-2, 256-2, 256-2, vvv, 256-1, 256-2, 256-1, 256-1, 256-3, 256-1, 0, 256-2, 0, 256-1, 0, 256-1, 0
MinCapXData:
	.byte 0, 0, 0, vvv, 0, 0, 8, 8, 0, 0, 0, 0, 0, 0, 0, 8, 0
SoftCapXData:
	.byte 40, 40, 40, vvv, 24, 40, 32, 48, 4, 4, 0, 40, 0, 24, 0, 48, 25
HardCapXData:
	.byte 64, 64, 64, vvv, 48, 64, 32, 48, 4, 4, 0, 64, 0, 48, 0, 48, 48
;FromXData:
SetYData:
	.byte vvv, 256-70, vvv, vvv, 256-40, 256-110, 256-32, 256-20, 20, vvv, 256-110, 16, vvv, vvv, 256-48, 0
AccelYData:
	.byte 0, 2, 9, vvv, 1, 1, 4, 1, 2, 10, 0, 4, 8, 256-4, 0, 8, 0
AccelYSubData:	;just for keeping the original jump height!
	.byte 0, 0, 0, vvv, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0	;AccelYSubData[1]=128
SoftCapYData:
	.byte 0, 64, 64, vvv, 32, 48, 64, 48, 0, 80, 0, 64, 64, 32, 0, 64, 0
HardCapYData:
	.byte 0, 64, 64, vvv, 32, 64, 64, 48, 0, 80, 0, 64, 64, 64, 0, 64, 0