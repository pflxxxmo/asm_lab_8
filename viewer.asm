org 100h  
.code
main:  
    mov ax, 03h
    int 10h    
    call getNameOfFile
     
    mov ah, 09h
    lea dx, nameOfFile
    int 21h 
; open existing file
    call openFile
    cmp errorOpening, 1
    je errorExit
    mov fileHandle, ax
; read file
    call clearScreen
    
    mov ah, 9h
    mov dx,offset controlMessage
    int 21h
    mov ah, 00h
    int 16h
    call clearScreen
             
    call displayFileContents
    mov row, 0
    mov column, 0
     
workingWithFileLoop:
    mov ah, 00h
    int 16h
    cmp al, 1Bh
    je closeFile
    cmp ah, 4Bh
    je moveLeft
    cmp ah, 4Dh
    je moveRight
    cmp ah, 48h
    je moveUp
    cmp ah, 50h
    je moveDown
    jmp workingWithFileLoop


moveLeft:
    mov dh, row
    cmp column, 0
    je previousLine
    dec column
    mov dl, column
    call setCursorPosition
    jmp workingWithFileLoop

moveUp:
    cmp row, 0
    je scrollUp  ; scroll up proc here
    dec row
    mov dh, row
    mov dl, column
    call setCursorPosition
    jmp workingWithFileLoop
    
moveRight:
    mov dh, row
    cmp column, 79
    je nextLine
    inc column
    mov dl, column
    call setCursorPosition
    jmp workingWithFileLoop
    
moveDown:
    cmp row, 24
    je scrollDown
    inc row
    mov dh, row
    mov dl, column
    call setCursorPosition
    jmp workingWithFileLoop                 

nextLine:
    inc row
    cmp row, 24
    je workingWithFileLoop
    mov column, -1
    jmp moveRight
    
scrollDown:
    call scrollDownScreen
    mov dh, row
    mov dl, column
    call setCursorPosition
    jmp workingWithFileLoop

scrollUp:
    call scrollUpScreen
    mov dh, row
    mov dl, column
    call setCursorPosition
    jmp workingWithFileLoop

previousLine:
    dec row
    cmp row, 0
    je workingWithFileLoop
    mov column, 80
    jmp moveLeft
     
closeFile:    
    mov ah, 3Eh
    int 21h
    jmp exit
    
errorExit:
    cmp  ax, 02h
    je nameOfFileNotFound
    cmp ax, 03h
    je pathOfFileNotFound
    mov dx, offset unknownError
    jmp print
nameOfFileNotFound:
    mov dx, offset fileNotFound
    jmp print
pathOfFileNotFound:
    mov dx, offset pathNotFound
print:
    mov ah, 09h
    int 21h
       
exit:
    call clearScreen    
    mov ah, 4ch
    int 21h
      
getNameOfFile proc
    push ax
    push bx
    push cx
    push dx
    
    xor cx, cx
    mov cl, es:[80h]
    cmp cl, 0
    je  getNameExit
    mov di, 82h
    lea si, nameOfFile
getSymbols:
    mov al, es:[di]
    cmp al, 0Dh
    je parametersEnded
    cmp al, ' '
    je getNameExit
    mov [si], al
    inc di
    inc si
    jmp getSymbols

parametersEnded:
    inc si
    mov byte ptr [si], 0    

getNameExit:    
    pop dx
    pop cx
    pop bx
    pop ax
    ret
getNameOfFile endp

openFile proc
; open file for reading
; output: file identifier
push dx

xor ax, ax
lea dx, nameOfFile

mov ax, 3D00h
int 21h
jnc end_openFile
mov errorOpening, 1
      
end_openFile:
pop dx
ret 


openFile endp

;clear screen proc
clearScreen proc
    push ax
    push bx
    push cx
    push dx
    
    mov ah, 00
    mov al, 03
    int 10h
    
    pop dx
    pop cx
    pop bx
    pop ax
    ret
clearScreen endp    

checkEnd proc
    push ax
    push bx
    push cx
    push dx
    
    xor bh, bh
    mov ah, 03h
    int 10h
    
    cmp dh, screenEndCoordinates
    jne endCheckEnd
    mov screenEnd, 1
endCheckEnd:    
    pop dx
    pop cx
    pop bx
    pop ax
    ret
checkEnd endp

setCursorPosition proc  
    ; input: dh - row
    ;        dl - column 
    push ax
    push bx
    push cx
    push dx
    
    xor bx, bx
    mov ah, 02h
    int 10h
    
    pop dx
    pop cx
    pop bx
    pop ax
    ret
setCursorPosition endp

displayFileContents proc
    push ax
    push bx
    push cx
    push dx
    
    xor ax, ax
    xor cx, cx
    xor dx, dx
              
    mov bx, fileHandle
    mov dx, currentOffset
    mov ax, 4200h ; set pointer at the beginning of the file
    int 21h
    
    mov dh, 0
    mov dl, 0
    call setCursorPosition
              
readFile:
    call checkEnd
    cmp screenEnd, 1
    je writeToEnd
    mov ah, 3Fh
    mov cx, 1
    lea dx, buffer
    int 21h
    cmp ax, cx
    jnz displayFileContentsEnd      ; EOF
    mov dl, buffer
    mov ah, 2
    int 21h
    inc End
    jmp readFile
    inc column
writeToEnd:
    cmp column, 79
    je displayFileContentsEnd
    mov ah, 3Fh
    mov cx, 1
    lea dx, buffer
    int 21h
    cmp ax, cx
    jnz displayFileContentsEnd      ; EOF
    mov dl, buffer
    cmp dl, 10
    je displayFileContentsEnd
    mov ah, 2
    int 21h
    inc column
    inc End
    jmp writeToEnd    
    
displayFileContentsEnd:
    mov column, 0
    mov dh, 0
    mov dl, 0
    call setCursorPosition
    mov screenEnd, 0
    pop dx
    pop cx
    pop bx
    pop ax
    
    ret
displayFileContents endp

findOffsetForNewLine proc
    push ax
    push bx
    push cx
    push dx
    
    mov dh, 0
    mov dl, 0
    call setCursorPosition
    xor bh, bh      ; page number
stringLoop:
    cmp dl, 80
    je offsetFound
    mov ah, 08h    
    int 10h
    cmp al, Ah
    je offsetFound
    cmp al, 0
    je offsetFound
    inc temp
    inc Start
    inc dl 
    call setCursorPosition
    jmp stringLoop

offsetFound:
    ;inc offsetStart    
    pop dx
    pop cx
    pop bx
    pop ax
    ret
findOffsetForNewLine endp
 
scrollDownScreen proc
    push ax
    push bx
    push cx
    push dx
    
    call findOffsetForNewLine
    mov cx, Start 
    call clearScreen   
;set cursor at the beginning
    mov dh, 0
    mov dl, 0
; set new file pointer
    mov currentOffset, cx
    call displayFileContents      
    
    pop dx
    pop cx
    pop bx
    pop ax
    
    ret
scrollDownScreen endp 

scrollUpScreen proc
    push ax
    push bx
    push cx
    push dx
    
    cmp Start, 0
    je endScrollUpScreen
    
    mov temp, 0
    
    mov bx, fileHandle
    mov ah, 42h
    mov al, 00h
    mov dx, Start
    dec dx
    int 21h
backwardsLoop:
    cmp temp, 80
    je endScrollUpScreen     
    mov ah, 3Fh
    mov cx, 1
    lea dx, buffer
    int 21h
    mov dl, buffer
    cmp dl, 0Ah
    je endScrollUpScreen
    dec Start
    inc temp
    mov bx, fileHandle
    mov ah, 42h
    mov al, 00h
    mov dx, Start
    int 21h
    jmp backwardsLoop  
    
endScrollUpScreen:
    call clearScreen   
;set cursor at the beginning
    mov dh, 0
    mov dl, 0
; set new file pointer
    
    mov cx, Start
    mov currentOffset, cx
    call displayFileContents    
    
    pop dx
    pop cx
    pop bx
    pop ax
    
    ret
scrollUpScreen endp
        

nameOfFile      db       30 dup('$')
fileHandle    dw       0000h

buffer              db      1
screenEnd           db      0
errorOpening        db      0
Start         dw      0
End           dw      0
currentOffset       dw      0000h
screenEndCoordinates        db      24  
row                 db      0
column              db      0
temp                db      0

fileNotFound   db      'File not found', 13, 10, '$'
pathNotFound   db      'Path not found', 13, 10, '$'
unknownError        db      'Error occured', 13, 10, '$'

controlMessage db 09h,09h,09h,09h,"CONTROLS:", 13,10
               db 09h,09h,09h,09h,"UP - Move cursor up", 13, 10
               db 09h,09h,09h,09h,"DOWN - Move cursor down", 13, 10
               db 09h,09h,09h,09h,"LEFT - Move cursor left", 13, 10
               db 09h,09h,09h,09h,"RIGNT - Move cursor right", 13, 10
               db 09h,09h,09h,09h,"ESC - Exit viewer", 13, 10
               db 13, 10
               db 13, 10
               db "Press any key to continue...", 13, 10, '$'

end main
