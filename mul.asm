cseg segment PARA PUBLIC 'code'
assume cs:cseg
start:
    push bp
    mov bp, sp

    mov ax, [ss:bp+6+2]
    mov bx, [ss:bp+6]

    xor dx, dx
    imul bx

    mov [ss:bp+6+4], ax

    pop bp
retf
cseg ends
end start