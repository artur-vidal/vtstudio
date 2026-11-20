# Rolagem de dados

Abra `editor/ExampleScene.tscn` e clique em **Rolar dados**, no canto superior
esquerdo. `DiceRoller.tscn` tambÃ©m pode ser instanciada sobre outra cena ou
executada sozinha para testar a interface.

A primeira abertura inicia zerada; o botão mostra **Selecione seus dados** em branco.
Selecione quantidades de d4, d6, d8, d10, d12 e d20. Cada tipo pode somar seus
valores ou considerar apenas o maior. O total central soma as contribuiÃ§Ãµes de
todos os conjuntos. Os limites sÃ£o 50 dados por tipo e 100 por rolagem.

Um conjunto recebe uma estrela e ativa a celebraÃ§Ã£o quando sua soma Ã©
**estritamente maior que 80%** do mÃ¡ximo possÃ­vel, ou quando, em modo maior,
obtÃ©m o valor mÃ¡ximo do dado. Exatamente 80% nÃ£o Ã© especial. No d10, o zero
impresso representa 10; no d4, leia os nÃºmeros comuns no vÃ©rtice superior.

O sorteio usa um RandomNumberGenerator separado do movimento. Os dados sÃ£o
RigidBody3D com colisões convexas e gravidade. Cada dado parte de uma trajetória
separada, sem colisão com outros dados, para impedir empilhamento. Após 1,4
segundo de queda livre, a aterrissagem dirigida de 1,45 segundo orienta a face
ainda no ar e termina com um pequeno quique. A altura de contato é recalculada
pela geometria em cada passo, evitando que a malha atravesse o chão. A face
visível é conferida antes de liberar o resultado; não há troca de face depois
do repouso. O sorteio continua independente da simulação.
Depois de os dados pararem, há uma pausa de 1 segundo para ler suas faces
antes de revelar o total. A seleÃ§Ã£o entra deslizando em 0,32 segundo e sai
em 0,24 segundo ao rolar; o fechamento leva 0,25 segundo.

O botÃ£o Rolar de novo mantÃ©m a seleÃ§Ã£o; Editar permite alterÃ¡-la. Fechar ou
Escape cancela a animaÃ§Ã£o, inclusive durante a pausa, restaura os controles do
editor e libera o foco do teclado. A interface usa
os componentes Botao e Dropdown existentes e as cores de `pallete.tres`, sem
modificar esses componentes.

`roll_completed(result)` entrega grupos, valores individuais, contribuiÃ§Ãµes,
total e indicador especial. Os detalhes da validaÃ§Ã£o estÃ£o em `dice_roll.gd`.
O palco usa seu prÃ³prio World3D, sem alterar colisÃµes ou iluminaÃ§Ã£o do mapa.

Testes: `dice_roll_test.gd`, `dice_panel_test.gd` e `dice_integration_test.gd`
em `res://tests`, executÃ¡veis com `godot --headless --path app --script ...`.
No PowerShell com o executÃ¡vel grÃ¡fico do Godot, finalize o comando com
`2>&1 | Out-String` para aguardar e capturar a saÃ­da.

`dice_landing_test.gd` verifica a trajetória inteira e o primeiro contato com o chão.
`dice_face_audit.gd` gera uma imagem com as 60 faces e os valores esperados para
conferência visual da textura; `DICE_AUDIT_IMAGE` define o destino do PNG.

O d4 usa uma pose de apresentação inclinada em 45 graus para expor o vértice superior.

Tray contacts use rotated convex geometry to prevent floor penetration.
Texture filtering uses nearest without mipmaps. D4 yaw comes from a supporting-face vertex.
