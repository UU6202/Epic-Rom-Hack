LandingExtraRoutine:
	ldy #StateNormal	;for 0-7
	lda Player_State
	sec
	sbc #8
	bmi @SetState	;8-11
	ldy #StateGPLand
	sbc #4
	bmi @SetState
	ldy #StateUnderwaterGPLand	;12
	sbc #1
	bmi @SetState
	ldy #StateSwimming	;13
	sbc #1
	bmi @SetState
	ldy #StateUnderwaterGPLand	;14
	sbc #1
	bmi @SetState
	ldy #StateDiveLand	;15-16
	sbc #2
	bmi @SetState
	ldy #StateUnderwaterDive	;17
	sbc #1
	bmi @SetState
	ldy #StateNormal	;18
	sbc #1
	bmi @SetState
@SetState:
	sty Player_State
	
	lda OnGroundTmr
	bne @Not1stFGround
	lda #$10
	sta GPLandTmr	;|DiveLandTmr
@Not1stFGround:

	inc OnGroundTmr
	bne @NotOnGroundOverflow
	dec OnGroundTmr
@NotOnGroundOverflow:
	rts