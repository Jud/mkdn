# Math Rendering Test

## Block Math (Code Fence)

```math
\int_0^\infty e^{-x^2} dx = \frac{\sqrt{\pi}}{2}
```

```latex
\sum_{n=1}^{\infty} \frac{1}{n^2} = \frac{\pi^2}{6}
```

```tex
\lim_{x \to 0} \frac{\sin x}{x} = 1
```

## Block Math ($$)

$$E = mc^2$$

$$\frac{d}{dx}\left(\int_0^x f(t)\,dt\right) = f(x)$$

## Inline Math

The quadratic formula is $x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}$ for any $ax^2 + bx + c = 0$.

## Multiple Inline

Given $x = 1$ and $y = 2$, then $x + y = 3$.

## Escaped Dollars

The price is \$42.00 and \$100.

## Fallback (Unsupported)

$$\begin{align} x &= 1 \\ y &= 2 \end{align}$$

## Math in Headings

### The $\pi$ constant

### Euler's $e^{i\pi} + 1 = 0$

## Math in Lists

- The area of a circle is $A = \pi r^2$
- The circumference is $C = 2\pi r$
- The volume of a sphere is $V = \frac{4}{3}\pi r^3$

1. First we compute $\alpha$
2. Then we find $\beta = 2\alpha$
3. Finally $\gamma = \alpha + \beta$

## Math in Blockquotes

> The most beautiful equation is $e^{i\pi} + 1 = 0$.
>
> It connects five fundamental constants.

## Mixed Content

Regular text with $\alpha + \beta = \gamma$ inline and a block:

$$\sum_{i=1}^{n} i = \frac{n(n+1)}{2}$$

More text follows.

## Greek Letters

Inline Greek: $\alpha$, $\beta$, $\gamma$, $\delta$, $\epsilon$, $\theta$, $\lambda$, $\mu$, $\sigma$, $\omega$.

## Operators and Relations

$a \leq b$, $x \geq y$, $p \neq q$, $A \subset B$, $x \in S$, $\forall x$, $\exists y$.

## Fractions and Roots

$\frac{a}{b}$, $\frac{1}{1+\frac{1}{x}}$, $\sqrt{x}$, $\sqrt[3]{8}$.

## Matrices (may fallback)

$$\begin{pmatrix} a & b \\ c & d \end{pmatrix}$$

## Edge Cases

A single dollar sign: $

Two dollar signs together: $$

Dollar amount: $5 is not math because of whitespace after dollar.

Empty math delimiters: $$ should not render.

Unclosed delimiter: $x^2 has no closing dollar.
