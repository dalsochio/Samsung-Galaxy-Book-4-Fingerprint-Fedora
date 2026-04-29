# Correção do Leitor de Impressões Digitais do Samsung Galaxy Book 4 (Fedora)

**Idiomas:** [English](README.md) · **Português (Brasil)** · [Español](README.es.md)

Faz o leitor de impressões digitais do **Samsung Galaxy Book 4** funcionar no **Fedora**
(tela de login, tela de bloqueio e `sudo`).

> **Resumo para usuários leigos**
>
> 1. Abra um terminal.
> 2. Cole os quatro comandos da seção [Início rápido](#início-rápido).
> 3. Pronto. Você pode fazer login e usar o `sudo` com o dedo.

---

## Como fica visualmente

Após a instalação, rode `./fingerprint-enroll.sh` para gerenciar suas digitais.
O programa exibe uma visualização das suas mãos em tempo real — dedos cadastrados
aparecem como `●`, os não cadastrados mostram seu número para você escolher qual registrar:

```
Fingerprint manager (user: seuusuario)

     Left hand                       Right hand

          _.-._                          _.-._
        _|1|2|3|\                       /|●|7|8|_
       |0| | | ||                       || | | |9|
       | | | | ||                       || | | | |
       | `     ||_                     _||     ` |
       ;       /4//                   \\●\       ;
       |        //                     \\        |
        \      //                       \\      /
         |    | |                       | |    |
         |    | |                       | |    |

  e) Enroll a new finger
  v) Verify a finger (test)
  d) Delete a finger
  D) Delete ALL fingers
  l) List enrolled fingers
  q) Quit

>
```

> Em um terminal real os `●` ficam destacados em verde e os dígitos não cadastrados
> aparecem em cinza. O mesmo desenho é exibido sempre que você cadastra, verifica
> ou apaga um dedo.

---

## Isso vai funcionar para mim?

Você precisa que as **três** condições sejam verdadeiras:

- [x] Você tem um **Samsung Galaxy Book 4** (Pro, Ultra ou 360).
- [x] Você está usando **Fedora** (43 e 44 beta confirmados; 42 provavelmente funciona).
- [x] Você vê o sensor ao rodar:
      ```bash
      lsusb | grep 2808:6553
      ```
      Se uma linha aparecer, está ótimo. Se não aparecer nada, este fix
      **não vai** funcionar para você — ele é específico para esse sensor.

---

## Início rápido

Abra um terminal e rode:

```bash
git clone https://github.com/dalsochio/Samsung-Galaxy-Book-4-Fingerprint-Fedora.git
cd Samsung-Galaxy-Book-4-Fingerprint-Fedora
chmod +x install.sh fingerprint-enroll.sh uninstall.sh

# 1) Instala o driver corrigido e habilita login por digital (pede sua senha):
sudo ./install.sh

# 2) Cadastra seu dedo (rode como SEU usuário, NÃO com sudo):
./fingerprint-enroll.sh
```

Só isso. Depois do passo 2 você pode:

- Tocar o sensor na **tela de login** em vez de digitar a senha.
- Tocar o sensor quando rodar `sudo` no terminal.
- Tocar o sensor na **tela de bloqueio**.

> **Por que dois passos em contas diferentes?**
> O passo 1 precisa de root para instalar pacotes do sistema.
> O passo 2 deve rodar com seu usuário normal porque o sistema de permissões
> do desktop (polkit) só autoriza o cadastro de digitais para o usuário
> que está sentado na frente do computador. Se rodar o passo 2 com `sudo`
> você vai receber um erro de `PermissionDenied`.

---

## O que esperar ao cadastrar seu dedo

Ao rodar `./fingerprint-enroll.sh`, escolha `e` no menu, depois selecione um dedo. Em seguida:

- Coloque o dedo **plano e centralizado** no sensor.
- **Levante completamente** o dedo entre os toques.
- Repita **de 8 a 15 vezes** até ver `enroll-completed`.
- O programa vai oferecer **testar** o dedo imediatamente.

Se errar, continue — o sensor só conta os toques bons.

### O que as mensagens significam

| Mensagem                       | O que significa                              |
|--------------------------------|----------------------------------------------|
| `enroll-stage-passed`          | OK, esse toque funcionou. Continue.          |
| `enroll-finger-not-centered`   | Você errou o sensor. Tente de novo.          |
| `enroll-retry-scan`            | Levante o dedo e toque de novo.              |
| `enroll-completed`             | Pronto! Seu dedo está cadastrado.            |

Você pode cadastrar **quantos dedos quiser**. Escolha `e` novamente no menu,
ou rode `./fingerprint-enroll.sh enroll left-thumb`.

---

## Problemas comuns

### O `sudo` não pede a digital

Verifique se o recurso está ativado:

```bash
authselect current
```

Se a saída não mencionar `with-fingerprint`, rode:

```bash
sudo authselect enable-feature with-fingerprint
sudo authselect apply-changes
```

### O sensor para de funcionar após suspender o computador

O instalador já inclui uma correção para isso (um pequeno serviço do systemd que
reinicia o `fprintd` ao acordar). Se falhar mesmo assim:

```bash
sudo systemctl restart fprintd
```

### `failed to claim device: Remote peer disconnected`

O `fprintd` travou. Na maioria das vezes significa que uma biblioteca antiga está no caminho.
Reinstale:

```bash
sudo ./uninstall.sh
sudo ./install.sh
```

### Continua aparecendo `enroll-finger-not-centered`

- Use o **centro** do dedo, não a ponta.
- Cubra o sensor completamente.
- Fique parado até a mensagem mudar.

### A digital parou de funcionar após uma atualização do sistema

Pode acontecer se um `dnf upgrade` sobrescrever o driver corrigido. Basta rodar de novo:

```bash
sudo ./install.sh
```

---

## Desinstalar / Reverter

Para desfazer tudo:

```bash
sudo ./uninstall.sh
```

Isso vai **apagar todas as digitais cadastradas** e deixar o sistema como estava.
O script pede confirmação; passe `--yes` para pular a pergunta.

---

---

## Referência técnica (para usuários avançados)

### Por que isso existe

O `libfprint` padrão do Fedora ainda não suporta o sensor FocalTech Match-on-Chip
que vem com o Galaxy Book 4 (USB ID `2808:6553`). A correção é um `libfprint`
com patch baseado no MR #554 do libfprint por Sid1803, não mesclado ainda ao upstream.

Este repositório é o equivalente Fedora de
[ishashanknigam/Samsung-Galaxy-Book-4-Fingerprint-Ubuntu](https://github.com/ishashanknigam/Samsung-Galaxy-Book-4-Fingerprint-Ubuntu),
que distribui arquivos `.deb` Debian com o mesmo patch. O instalador usa o COPR
[`hichambel/libfprint-galaxybook`](https://copr.fedorainfracloud.org/coprs/hichambel/libfprint-galaxybook/),
compilado contra as bibliotecas do Fedora.

> Por que não reutilizar o `.so` Debian? Porque ele é ligado dinamicamente contra
> símbolos do `libgusb` marcados como `LIBGUSB_0.1.0`, enquanto o `libgusb` do Fedora
> exporta as mesmas funções marcadas como `LIBGUSB_0.2.8`. Copiar o binário Debian
> para `/usr/lib64` causa `undefined symbol: g_usb_device_get_interfaces` e o `fprintd` trava.

### Compatibilidade com versões do Fedora

| Fedora        | Status                                                                      |
|---------------|-----------------------------------------------------------------------------|
| 40 / 41       | Não testado. Usará o fallback `fedora-43`. Pode falhar nas dependências.    |
| 42            | Não testado. Usará o fallback `fedora-43`; deve funcionar.                  |
| 43            | **Build nativo, totalmente suportado.**                                     |
| 44 (beta)     | **Testado, funciona via fallback `fedora-43`.**                             |
| 45+           | Melhor esforço enquanto o ABI de glib2 / libgusb / libusb1 for compatível. |

### Versionlock

O `install.sh` trava a versão do `libfprint` com `dnf versionlock` automaticamente.
Sem isso, um `sudo dnf upgrade` eventualmente substituiria o build corrigido
pelo padrão do Fedora, quebrando o sensor silenciosamente.

Você vai ver isso no `dnf upgrade`:

```
Package "libfprint" excluded by versionlock plugin.
```

Isso é esperado — é o travamento funcionando.

Para destravar (por exemplo, quando o COPR publicar um build para sua versão do Fedora):

```bash
sudo dnf versionlock list                  # ver o que está travado
sudo dnf versionlock delete libfprint      # destravar
```

Para re-aplicar depois:

```bash
sudo dnf versionlock add libfprint
```

### Instalação manual

```bash
sudo dnf install -y dnf-plugins-core
sudo dnf copr enable -y hichambel/libfprint-galaxybook
sudo dnf install -y fprintd fprintd-pam libfprint
sudo dnf reinstall -y libfprint
sudo authselect enable-feature with-fingerprint
sudo authselect apply-changes
sudo systemctl restart fprintd
```

### Comandos de verificação

```bash
rpm -qf /usr/lib64/libfprint-2.so.2   # deve conter "galaxybook"
systemctl status fprintd
ldd /usr/libexec/fprintd | grep fprint
lsusb | grep 2808:6553
fprintd-list "$USER"
```

### SELinux

O RPM do COPR já vem com os labels SELinux corretos. Se suspeitar de bloqueio:

```bash
sudo ausearch -m AVC -ts recent
```

---

## Créditos

- Fix original Ubuntu / Debian:
  [ishashanknigam](https://github.com/ishashanknigam/Samsung-Galaxy-Book-4-Fingerprint-Ubuntu).
- Driver FocalTech MoC: libfprint MR #554 por Sid1803.
- Build COPR para Fedora:
  [`hichambel/libfprint-galaxybook`](https://copr.fedorainfracloud.org/coprs/hichambel/libfprint-galaxybook/).
- Port para Fedora (este repo): scripts, hook systemd, helper de cadastro de múltiplos dedos,
  versionlock automático, documentação — desenvolvido com auxílio do **Claude Sonnet 4.5**.
- Desenho ASCII das mãos adaptado de
  [Joan G. Stark (Spunk)](https://www.asciiart.eu/art/f8977d5ed396941a).

---

## Aviso

Este instalador substitui uma biblioteca do sistema via COPR de terceiros e
modifica a configuração do PAM. Use por sua conta e risco.
