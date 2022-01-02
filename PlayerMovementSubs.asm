GPTmr = $07a3
GPLandTmr = $07a3	;share, since they do not happen at the same time
DiveLandTmr = $07a3
;Player_Y_Speed_Exag = $54
Multiple_Jump_Ctr = $07e3
WaterFriction = $0040
OnGroundTmr = $07a5

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
	lda #$00
	ldy Player_MovingDir,x
@NotZeroSpeed:
	bpl @SetSpeedAndDir	;bra for zero and neutral
	eor #$ff
	clc
	adc #$01
	iny
@SetSpeedAndDir:
	sta Player_XSpeedAbsolute
	sty Player_MovingDir,x
	;lda Player_Y_Speed,x
	;php	;save the sign as y speed exag might overflow
	;sta Player_Y_Speed_Exag,x
	;lda Player_Y_MoveForce,x
	;asl
	;rol Player_Y_Speed_Exag,x
	;asl
	;rol Player_Y_Speed_Exag,x
	;asl
	;rol Player_Y_Speed_Exag,x
	;asl
	;rol Player_Y_Speed_Exag,x
	;ror YSpeedBit9	;in case of overflow! this stores the sign
	
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
	.word StateSubDiveLand
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
StateDiveLand = 16
StateUnderwaterDive = 17
StateWallSlide = 18

StateSubNormal:


	;todo jsr check tile above player
	lda MyJoypadHeld,x
	and #Down_Dir
	beq @Uncrouch
	inc CrouchingFlag,x	;now as a counter instead of always holding %00000100
	bne @UncrouchEnd	;bra
	lda #$ff	;except overflowed! $00->$ff
@Uncrouch:	;todo: reset CrouchingFlag when landing so that unconsecutive crouches can be differed
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
	lda OnGroundTmr,x	;not crouch => triple jump
	cmp #$09
	bcs @FailTriple
	lda Player_XSpeedAbsolute,x
	lsr
	lsr
	lsr
	lsr
	clc
	adc #$ff
	cmp Multiple_Jump_Ctr,x	;double jump requires 16 x speed
	bmi @FailTriple	;triple jump requires 32 x speed
	lda Multiple_Jump_Ctr,x
	cmp #$02
	bcs @FailTriple	;if last one was triple, reset
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
	lda MyJoypadHeld,x
	and #A_Button
	bne @Held
	inc Player_State,x	;state -> falling
@Held:
StateSubBackflip:
StateSubGPJump:
	jsr ChkGP
	
	lda Player_Y_Speed,x
	bmi @NotFalling
	lda #StateFalling	;Y speed >= 0 => falling
	sta Player_State,x
@NotFalling:
	rts
	
StateSubFalling:
StateSubFloating:
	lda #$00
	sta OnGroundTmr,x
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
	jsr NewStateX
	jmp NewStateY
@NotDive:
	rts
	
StateSubGPReady:
	lda MyJoypadHeld,x
	and #Left_Dir|Right_Dir
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
	ldy Player_Y_Speed	;if y speed < 2
	cpy #$02
	bmi @NotExitUGPFade
	lda #StateSwimming	;finish the fade
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
	
StateSubDiveLand:
	lda MyJoypadPressed,x
	and #A_Button
	beq @NotJump
	lda MyJoypadHeld,x	;A button pressed
	and #Down_Dir
	beq @NotLJ
	lda Player_XSpeedAbsolute	;is crouch => either backflip, crouch jump or long jump
	cmp #$24	;lj speed threshold
	bmi @NotLJ
	lda #StateLJ	;is lj
	sta Player_State,x	;update state
	jmp NewStateY
	
@NotLJ:	;normal jump, a = 0
	sta Multiple_Jump_Ctr,x
	lda #StateJumping
	sta Player_State,x	;update state
	jsr NewStateY
	jmp NewStateYFromX

@NotJump:
	dec DiveLandTmr,x
	bne @NotExitDiveLand
	lda #StateNormal
	sta Player_State,x
@NotExitDiveLand:
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
	
NewStateY:
	lda #$00
	sta OnGroundTmr,x
	ldy Player_State,x
	lda SetYHighData,y
	sta Player_Y_Speed,x
	lda SetYLowData,y
	sta Player_Y_MoveForce,x
	rts
	
NewStateYFromX:	;adds X speed / 4 to initial Y speed as bonus
	lda Player_XSpeedAbsolute
	asl	;*4
	asl
	sta $00
	lda Multiple_Jump_Ctr,x
	ror	;*64
	ror
	ror	;and clc
	adc $00	;double jump => +64, triple jump => +128 (can reach 6+3/16 blocks high with 40 x speed)
	sta $00
	lda Player_Y_MoveForce,x
	sec	;the ++ here
	sbc $00
	sta Player_Y_MoveForce,x
	lda Player_Y_Speed,x
	sbc #$00
	sta Player_Y_Speed,x
	;rts
	pla
	pla
	
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

	lda Player_Y_Speed,x
	cmp SoftCapYData,y ;exceed soft cap?
	bpl @IsSoftExceed
@NotSoftExceed:
	pha
	lda Player_Y_MoveForce,x
	clc
	adc AccelYLowData,y
	sta Player_Y_MoveForce,x
	pla
	adc AccelYHighData,y
@IsSoftExceed:
	cmp HardCapYData,y	;min(y speed, y hard cap)
	bmi @NotHardExceed
	lda #$00
	sta Player_Y_MoveForce,x
	lda HardCapYData,y
@NotHardExceed:

	sta Player_Y_Speed,x
	;lsr
	;ror Player_Y_MoveForce,x
	;lsr
	;ror Player_Y_MoveForce,x
	;lsr
	;ror Player_Y_MoveForce,x
	;lsr
	;ror Player_Y_MoveForce,x
	;bit YSpeedBit9
	;bpl @Positive
	;ora #$f0
;@Positive:
	;sta Player_Y_Speed,x
	
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
	.byte vvv, vvv, vvv, vvv, vvv, vvv, 8, vvv, vvv, vvv, vvv, vvv, vvv, vvv, vvv, 32, vvv, 48
AccelXData:
	.byte 1, 1, 1, vvv, 1, 1, 2, 2, 0, 1, 0, 1, 0, 1, 0, 2, 256-2, 0
NeutralXData:
	.byte 256-1, 0, 0, vvv, 0, 0, 1, 0, 256-3, 256-1, 0, 0, 0, 0, 0, 2, 256-4, 0
DecelXData:
	.byte 256-2, 256-2, 256-2, vvv, 256-1, 256-2, 256-1, 256-1, 256-3, 256-1, 0, 256-2, 0, 256-1, 0, 256-1, 256-4, 0
MinCapXData:
	.byte 0, 0, 0, vvv, 0, 0, 8, 8, 0, 0, 0, 0, 0, 0, 0, 8, 0, 0
SoftCapXData:
	.byte 40, 40, 40, vvv, 24, 40, 32, 48, 4, 4, 0, 40, 0, 24, 0, 48, 48, 25
HardCapXData:
	.byte 64, 64, 64, vvv, 48, 64, 32, 48, 4, 4, 0, 64, 0, 48, 0, 48, 64, 48
;FromXData:
SetYHighData:
	.byte vvv, $fb, vvv, vvv, $fd, vvv, $f8, $fe, $fe, $01, vvv, $f8, $01, vvv, vvv, $fd, vvv, $00
SetYLowData:
	.byte vvv, $78, vvv, vvv, $70, vvv, $e0, $00, $a0, $40, vvv, $e0, $00, vvv, vvv, $00, vvv, $00
AccelYHighData:
	.byte 0, 0, 0, vvv, 0, 0, 0, 0, 0, 0, 0, 0, 0, 255, 0, 0, 0, 0
AccelYLowData:
	.byte $00, $28, $90, vvv, $10, $10, $40, $10, $20, $a0, $00, $40, $80, $c0, $00, $80, $00, $00
SoftCapYData:
	.byte 0, 4, 4, vvv, 2, 3, 4, 3, 0, 5, 0, 4, 4, 2, 0, 4, 0, 0
HardCapYData:
	.byte 0, 4, 4, vvv, 2, 4, 4, 3, 0, 5, 0, 4, 4, 4, 0, 4, 0, 0