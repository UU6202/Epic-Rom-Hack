;KonamiIndex == $0a means Konami Code activated
KonamiIndex = $07xx
KonamiSeq:
	.byte $08, $08, $04, $04, $02, $01, $02, $01, $40, $80
CheckKonami:
	ldy KonamiIndex
	cpy #$0a	;if activated, don't reset it
	bpl SkipKonami
	lda JoypadPressed	;(P1 only)
	beq SkipKonami	;if nothing is pressed, rts
	cmp KonamiSeq,y
	beq IncKonami	;if correct button, branch to increase index
	;otherwise reset index
ResetKonamiIndex:	;can be a sub alone
	lda $00
	sta KonamiIndex
	rts
IncKonami:
	inc KonamiIndex
SkipKonami:
	rts