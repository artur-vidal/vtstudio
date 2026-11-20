# Rolagem de dados

Abra `editor/ExampleScene.tscn` e clique em **Rolar dados**, no canto superior
esquerdo. `DiceRoller.tscn` também pode ser instanciada sobre outra cena ou
executada sozinha para testar a interface.

A primeira abertura inicia zerada; o botão mostra **Selecione seus dados** em branco.
Selecione quantidades de d4, d6, d8, d10, d12 e d20. Cada tipo pode somar seus
valores ou considerar apenas o maior. O total central soma as contribuições de
todos os conjuntos. Os limites são 50 dados por tipo e 100 por rolagem.

Um conjunto recebe uma estrela e ativa a celebração quando sua soma é
**estritamente maior que 80%** do máximo possível, ou quando, em modo maior,
obtém o valor máximo do dado. Exatamente 80% não é especial. No d10, o zero
impresso representa 10; no d4, leia os números comuns no vértice superior.

O sorteio usa um RandomNumberGenerator separado do movimento. Os dados são
RigidBody3D com gravidade e colisões nativas do Godot, incluindo entre dados.
A queda usa gravidade e contatos nativos, com giro livre durante os primeiros
0,8 a 1,1 segundos (variando entre dados). Depois, um controlador de velocidade
angular converge progressivamente para a face sorteada, sem impor a rotação
a cada quadro. A organização final espera no mínimo 2,5 segundos e a convergência
de todos os dados; dura 1,2 segundo e corrige apenas o pequeno resíduo angular.
As faces podem variar nos primeiros quiques, enquanto os dados ainda giram.
O resultado permanece fixo depois da acomodação. A pausa antes do total é de 1 segundo.
Depois de os dados pararem, há uma pausa de 1 segundo para ler suas faces
antes de revelar o total. A seleção entra deslizando em 0,32 segundo e sai
em 0,24 segundo ao rolar; o fechamento leva 0,25 segundo.

O botão Rolar de novo mantém a seleção; Editar permite alterá-la. Fechar ou
Escape cancela a animação, inclusive durante a pausa, restaura os controles do
editor e libera o foco do teclado. A interface usa
os componentes Botao e Dropdown existentes e as cores de `pallete.tres`, sem
modificar esses componentes.

`roll_completed(result)` entrega grupos, valores individuais, contribuições,
total e indicador especial. Os detalhes da validação estão em `dice_roll.gd`.
O palco usa seu próprio World3D, sem alterar colisões ou iluminação do mapa.

Testes: `dice_roll_test.gd`, `dice_panel_test.gd` e `dice_integration_test.gd`
em `res://tests`, executáveis com `godot --headless --path app --script ...`.
No PowerShell com o executável gráfico do Godot, finalize o comando com
`2>&1 | Out-String` para aguardar e capturar a saída.

`dice_landing_test.gd` verifica a trajetória inteira e o primeiro contato com o chão.
`dice_face_audit.gd` gera uma imagem com as 60 faces e os valores esperados para
conferência visual da textura; `DICE_AUDIT_IMAGE` define o destino do PNG.

O d4 usa uma pose de apresentação inclinada em 45 graus para expor o vértice superior.

Texture filtering uses nearest without mipmaps. D4 yaw comes from a supporting-face vertex.
