#define	YSET	$0359 ; Coordenada vertical do último ponto PLOTado/SETado.
#define	XSET	$035a ; Coordenada horizontal do último ponto PLOTado/SETado.
#define	VRAM	$8000 ; Endereço de início da VRAM.
#define	BANK0	$c879 ; Desabilita VRAM.
#define	BANK1	$c886 ; Habilita VRAM (bank switch).

	.org	$3e00
Mascara:
	.db	%00111100
	.db	%00111100
	.db	%11111111
	.db	%11000011
	.db	%11000011
	.db	%11111111
	.db	%00111100
	.db	%00111100
Sprite:
	.db	%00111100
	.db	%00000000
	.db	%10101010
	.db	%01000001
	.db	%01000001
	.db	%10101010
	.db	%00000000
	.db	%00111100

DesenhaSpriteComBank:

	; Habilita VRAM.

	call	BANK1

	; Prepara salto para desabilitar a VRAM (BANK0)
	; ao final da rotina.
	
	push	hl
	ld	hl,BANK0
	ex	(sp),hl

DesenhaSprite:

	; Mantém dados em registradores para acesso rápido.

	ld	a,(Opcoes)
	ld	e,a
	ld	ix,(EndSprite)
	ld	iy,(EndMascara)

CalculaEndSpriteVram:

	; Calcula posição inicial do sprite na VRAM.
	; [ VRAM + y * 32 + int(x / 8) ]
	
	; (Espera-se que a coordenada x esteja na faixa de 0~255,
	; mesmo em modo colorido, isto é deve ser o dobro do
	; valor que se usaria no modo GR.)
	
	ld	bc,(YSET) ; b = x, c = y.
	ld	a,c
	ld	c,b
	rra
	rr	c
	rra
	rr	c
	rra
	rr	c
	and	%00011111
	ld	b,a
	ld	hl,VRAM
	add	hl,bc
	ld	(EndSpriteVram),hl

	; Calcula byte de cor de fundo, se usando máscara e fundo opaco.

CalculaByteFundo:
	bit	1,e
	jr	z,CalculaByteFundoFim
	bit	2,e
	jr	z,CalculaByteFundoFim
	bit	0,e
	ld	a,(CorDeFundo)
	jr	nz,CalculaByteFundoColor
	
CalculaByteFundoMono:
	; Em modo monocromático:
	; %_______0 -> %00000000
	; %_______1 -> %11111111
	and	%00000001
	cpl
	inc	a
	jr	CalculaByteFundo0

CalculaByteFundoColor:
	; Em modo colorido:
	; %______00 -> %00000000
	; %______01 -> %01010101
	; %______10 -> %10101010
	; %______11 -> %11111111
	and	%00000011
	bit	0,a
	jr	z,CalculaByteFundoColor0
	or	%01010100
CalculaByteFundoColor0:
	bit	1,a
	jr	z,CalculaByteFundo0
	or	%10101000

CalculaByteFundo0:
	ld	(ByteCorDeFundo),a
CalculaByteFundoFim:

	; Prepara laço principal (para os 8 bytes do sprite...).

	ld	a,8

	; Laço principal.	

Laco8Bytes:
	push	af
	
TrataPaleta:
	; Obtém byte do sprite e aplica paleta, se necessário.

	ld	bc,TrataPaletaFim
	push	bc ; RET saltará para o fim do tratamento de paleta.

	bit	3,e ; Com ou sem paleta?
	jr	z,TrataSemPaleta ; Sem paleta: apenas obtém byte do sprite.

TrataComPaleta:
	bit	0,e ; Modo monocromático ou colorido?
	jr	nz,TrataComPaletaColor
	
TrataComPaletaMono:
	ld	bc,(PaletaDeCores) ; B = cor nº 1; C = cor nº 0.
	bit	0,b
	jr	nz,TrataComPaletaMono1_

TrataComPaletaMono0_:
	bit	0,c
	jr	nz,TrataComPaletaMono01

TrataComPaletaMono00:
	; Com paleta [0,0] em modo monocromático.
	; Nem precisamos obter o byte do sprite.
	; O byte terá todos os seus bits desligados.
	xor	a
	ret

TrataComPaletaMono01:
	; Com paleta [0,1] em modo monocromático.
	; Obtém byte do sprite e o inverte.
	ld	a,(ix+0)
	inc	ix
	cpl
	ret

TrataComPaletaMono1_:
	bit	0,c
	jr	nz,TrataComPaletaMono11

TrataComPaletaMono10:
	; Com paleta [1,0] em modo monocromático.
	; Tratamento igual ao caso sem paleta.

TrataSemPaleta:
	; Apenas obtém o byte do sprite.
	ld	a,(ix+0)
	inc	ix
	ret

TrataComPaletaMono11:
	; Com paleta [1,1] em modo monocromático.
	; Nem precisamos obter o byte do sprite.
	; O byte terá todos os seus bits ligados.
	ld	a,%11111111
	ret

TrataComPaletaColor:
	; Com paleta em modo colorido.
	; Obtém o byte do sprite e, por quatro vezes,
	; substitui os dois últimos bits pela cor correspondente
	; da paleta, girando o resultado em dois bits.

	ld	a,(ix+0)
	inc	ix
	push	de
	ld	b,4

TrataComPaletaColor0:

	ld	c,a
	and	%00000011
	ld	e,a
	ld	d,0	
	ld	hl,PaletaDeCores
	add	hl,de
	ld	a,(hl)
	and	%00000011
	ld	d,a
	ld	a,c
	and	%11111100
	or	d
	rrca
	rrca
	djnz	TrataComPaletaColor0
	pop	de
	ret

TrataPaletaFim:

	; Guarda o valor do byte do sprite em B.

	ld	b,a
	
TrataMascara:
	bit	1,e ; Com ou sem máscara?
	jr	z,TrataSemMascara

TrataComMascara:

	; Obtém byte da máscara em C.
	ld	c,(iy+0)
	inc	iy

	; A aplicação de paleta pode ter ativado bits da área transparente
	; do sprite. Usar a máscara para apagar esses bits.

	; ld	a,b
	and	c
	ld	b,a

	bit	2,e ; Fundo opaco ou transparente?
	jr	z,TrataMascaraFim

TrataComMascaraOpaco:
	; Aplicar cor de fundo à área transparente do sprite.
	; O fundo agora colorido fará parte do byte do sprite
	; e o byte será considerado integralmente ("sem máscara").

	ld	a,c
	cpl
	ld	hl,ByteCorDeFundo
	and	(hl)
	or	b
	ld	b,a

TrataSemMascara:
	; Se não houver máscara, assume uma máscara que cubra todo o
	; byte do sprite.

	ld	c,%11111111
TrataMascaraFim:

	ld 	hl,(EndSpriteVram) ; Recupera posição na VRAM a alterar.

TrataDeslocamento:
	; Se a coordenada x não for múltiplo de 8,
	; deslocar à direita bits do sprite e da máscara
	; para serem aplicados ao byte seguinte da VRAM.

	ld	a,(XSET)
	and	$07 ; A coordenada x é múltiplo de 8?
	jr	z,TrataDeslocamentoFim

TrataComDeslocamento:
	push	de
	ld	d,b ; Passa byte do sprite a D...
	ld	b,a ;  ...para usar B como contador do deslocamento.
	xor	a ; À direita: A = byte do sprite; E = byte da máscara,
	ld	e,a ; ambos inicialmente = %00000000.
TrataComDeslocamento0:
	rr	d ; Desloca byte do sprite 1 bit à direita (de D para A).
	rra
	rr	c ; Desloca byte da máscara 1 bit à direita (de C para E).
	rr	e
	djnz	TrataComDeslocamento0
	ld	b,d ; Devolve byte do sprite para B.
	ld	d,a ; Passa byte do sprite à direita para D.

	; Aplica byte do sprite à direita D à VRAM usando byte da máscara E.

	inc	hl ; Aponta para o byte à direita na VRAM.
	ld	a,e
	cpl
	and	(hl)
	or	d
	ld	(hl),a
	dec	hl ; Retorna ao byte à esquerda na VRAM.
	pop	de

TrataDeslocamentoFim:

	; Aplica byte do sprite B à VRAM usando byte da máscara C.

	ld	a,c
	cpl
	and	(hl)
	or	b
	ld	(hl),a
	
	; Avança para a próxima linha da tela (VRAM).

	ld	bc,+32
	add	hl,bc
	ld	(EndSpriteVram),hl

	; Fim do laço principal.

	pop	af
	dec	a
	jp	nz,Laco8Bytes

	; Retorna.

	ret

	; PARÂMETROS:

EndSprite:
	; Endereço da sequência de 8 bytes do sprite:
	.dw	Sprite

EndMascara:
	; Endereço da sequência de 8 bytes da máscara:
	.dw	Mascara

CorDeFundo:
	; Cor de fundo:
	;   - 0 ou 1 em modo monocromático.
	;   - 0 a 3 em modo colorido.
	.db	0

PaletaDeCores:
	; Paleta de cores:
	;   - 2 valores 0 a 1 em modo monocromático.
	;   - 4 valores 0 a 3 em modo colorido.
	.db	0,1,2,3

Opcoes:
	; Opções de funcionamento: |_|_|_|_|D|C|B|A|
	;   A = Seletor modo monocromático (0) / modo colorido (1).
	;   B = Seletor sem máscara (0) / com máscara (1).
	;   C = Seletor fundo transparente (0) / opaco (1).
	;   D = Seletor cores originais (0) / cores da paleta (1).
	.db	0	
	
	; VARIÁVEIS:
	
EndSpriteVram:
	; Endereço onde o próximo byte do sprite será colocado na VRAM.
	.dw	0

ByteCorDeFundo:
	; Padrão da cor de fundo repetida.
	.db	0
