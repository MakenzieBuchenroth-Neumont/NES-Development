.include "nes.inc"
.include "macros.inc"

.segment "HEADER"
.byte "NES", $1A
.byte 1
.byte 1
.byte $00
.byte $00, $00, $00, $00, $00, $00, $00, $00

.segment "RAM"
OAM_BUFFER: .res 256    ; 64 sprites × 4 bytes = 256

.segment "STARTUP"
.segment "CODE"

RESET:
    SEI
    CLD

    ; Disable APU IRQs
    LDX #$40
    STX JOYPAD2

    ; Stack setup
    LDX #$FF
    TXS

    ; Disable rendering
    LDA #$00
    STA PPU_CONTROL
    STA PPU_MASK
    STA APU_DM_CONTROL

    ; Wait for 4 reads to stabilize PPU latch
    BIT PPU_STATUS
    BIT PPU_STATUS
    BIT PPU_STATUS
    BIT PPU_STATUS

    ; Wait for next vblank before writing PPU data
    wait_for_vblank

    ; Load palette + tile data
    JSR LoadPalettes
    JSR LoadBackground

    ; Wait again before enabling rendering
    wait_for_vblank
    JSR EnableRendering

    ; Draw sprite AFTER enabling rendering, so it appears
    wait_for_vblank
    JSR DrawPlayer
Forever:
    JMP Forever

; ----------------------------

EnableRendering:
    LDA #PPUCTRL_ENABLE_NMI
    STA PPU_CONTROL

    LDA #PPUMASK_SHOW_BG | PPUMASK_SHOW_SPRITES
    STA PPU_MASK
    RTS

; ----------------------------

LoadPalettes:
    ; Set VRAM address to $3F00 (palette memory)
    vram_set_address PALETTE_ADDRESS

    LDX #$00
@loop:
    LDA palette, X
    STA PPU_VRAM_IO
    INX
    CPX #$20
    BNE @loop
    RTS

; ----------------------------

LoadBackground:
    ; Set VRAM address to start of Nametable 0
    vram_set_address NAME_TABLE_0_ADDRESS

    LDX #$00
@loop:
    LDA background, X
    STA PPU_VRAM_IO
    INX
    CPX #$F0
    BNE @loop
    RTS

.segment "RODATA"

palette:
  .byte $0F, $01, $11, $21  ; palette 0
  .byte $0F, $06, $16, $26  ; palette 1
  .byte $0F, $09, $19, $29  ; palette 2
  .byte $0F, $0C, $1C, $2C  ; palette 3
  .res 16, $0F              ; sprite palettes (fill with gray)

background:
  .res $F0, $00             ; blank screen for now

.segment "VECTORS"
.word 0
.word RESET
.word 0

; Renders a single sprite at (120, 100) using tile #$01 and palette 0
DrawPlayer:
    clear_oam OAM_BUFFER

    set_sprite OAM_BUFFER, 0, 100, $01, SPRITE_PALETTE_0, 120

    ; Tell PPU to transfer OAM_BUFFER to hardware OAM via DMA
    LDA #>OAM_BUFFER       ; High byte of $0200 = $02
    STA SPRITE_DMA         ; Starts DMA (takes 513 cycles)

    RTS
