-- TP-2  --- Implantation d'une sorte de Lisp          -*- coding: utf-8 -*-
{-# OPTIONS_GHC -Wall #-}

--Travail fait par:
--Jad Yammine 1067212
--Annie-Pier Coulombe 20000419


---------------------------------------------------------------------------
-- Importations de librairies et définitions de fonctions auxiliaires    --
---------------------------------------------------------------------------

import Text.ParserCombinators.Parsec -- Libraire d'analyse syntaxique (et lexicale).
import Data.Char        -- Conversion de Chars de/vers Int et autres
-- import Numeric       -- Pour la fonction showInt
import System.IO        -- Pour stdout, hPutStr
-- import Data.Maybe    -- Pour isJust and fromJust

---------------------------------------------------------------------------
-- La représentation interne des expressions de notre language           --
---------------------------------------------------------------------------
data Sexp = Snil                        -- La liste vide
          | Scons Sexp Sexp             -- Une paire
          | Ssym String                 -- Un symbole
          | Snum Int                    -- Un entier
          -- Génère automatiquement un pretty-printer et une fonction de
          -- comparaison structurelle.
          --deriving (Show, Eq)
-- Exemples:
-- (+ 2 3)  ==  (((() . +) . 2) . 3)
--          ==>  Scons (Scons (Scons Snil (Ssym "+")) (Snum 2))(Snum 3)
--                   
-- (/ (* (- 68 32) 5) 9)
--     ==  (((() . /) . (((() . *) . (((() . -) . 68) . 32)) . 5)) . 9)
--     ==>
-- Scons (Scons (Scons Snil (Ssym "/"))
--              (Scons (Scons (Scons Snil (Ssym "*"))
--                            (Scons (Scons (Scons Snil (Ssym "-"))
--                                          (Snum 68))
--                                   (Snum 32)))
--                     (Snum 5)))
--       (Snum 9)

---------------------------------------------------------------------------
-- Analyseur lexical                                                     --
---------------------------------------------------------------------------

pChar :: Char -> Parser ()
pChar c = do { _ <- char c; return () }

-- Les commentaires commencent par un point-virgule et se terminent
-- à la fin de la ligne.
pComment :: Parser ()
pComment = do { pChar ';'; _ <- many (satisfy (\c -> not (c == '\n')));
                pChar '\n'; return ()
              }
-- N'importe quelle combinaison d'espaces et de commentaires est considérée
-- comme du blanc.
pSpaces :: Parser ()
pSpaces = do { _ <- many (do { _ <- space ; return () } <|> pComment); return () }

-- Un numbre entier est composé de chiffres.
integer     :: Parser Int
integer = do c <- digit
             integer' (digitToInt c)
          <|> do _ <- satisfy (\c -> (c == '-'))
                 n <- integer
                 return (- n)
    where integer' :: Int -> Parser Int
          integer' n = do c <- digit
                          integer' (10 * n + (digitToInt c))
                       <|> return n

-- Les symboles sont constitués de caractères alphanumériques et de signes
-- de ponctuations.
pSymchar :: Parser Char
pSymchar    = alphaNum <|> satisfy (\c -> c `elem` "!@$%^&*_+-=:|/?<>")
pSymbol :: Parser Sexp
pSymbol= do { s <- many1 (pSymchar);
              return (case parse integer "" s of
                        Right n -> Snum n
                        _ -> Ssym s)
            }

---------------------------------------------------------------------------
-- Analyseur syntaxique                                                  --
---------------------------------------------------------------------------

-- La notation "'E" est équivalente à "(quote E)"
pQuote :: Parser Sexp
pQuote = do { pChar '\''; pSpaces; e <- pSexp;
              return (Scons (Scons Snil (Ssym "quote")) e) }

-- Une liste (Tsil) est de la forme ( [e .] {e} )
pTsil :: Parser Sexp
pTsil = do pChar '('
           pSpaces
           (do { pChar ')'; return Snil }
            <|> do hd <- (do e <- pSexp
                             pSpaces
                             (do pChar '.'
                                 pSpaces
                                 return e
                              <|> return (Scons Snil e)))
                   pLiat hd)
    where pLiat :: Sexp -> Parser Sexp
          pLiat hd = do pChar ')'
                        return hd
                 <|> do e <- pSexp
                        pSpaces
                        pLiat (Scons hd e)

-- Accepte n'importe quel caractère: utilisé en cas d'erreur.
pAny :: Parser (Maybe Char)
pAny = do { c <- anyChar ; return (Just c) } <|> return Nothing

-- Une Sexp peut-être une liste, un symbol ou un entier.
pSexpTop :: Parser Sexp
pSexpTop = do { pTsil <|> pQuote <|> pSymbol
                <|> do { x <- pAny;
                         case x of
                           Nothing -> pzero
                           Just c -> error ("Unexpected char '" ++ [c] ++ "'")
                       }
              }

-- On distingue l'analyse syntaxique d'une Sexp principale de celle d'une
-- sous-Sexp: si l'analyse d'une sous-Sexp échoue à EOF, c'est une erreur de
-- syntaxe alors que si l'analyse de la Sexp principale échoue cela peut être
-- tout à fait normal.
pSexp :: Parser Sexp
pSexp = pSexpTop <|> error "Unexpected end of stream"

-- Une séquence de Sexps.
pSexps :: Parser [Sexp]
pSexps = do pSpaces
            many (do e <- pSexpTop
                     pSpaces
                     return e)

-- Déclare que notre analyseur syntaxique peut-être utilisé pour la fonction
-- générique "read".
instance Read Sexp where
    readsPrec _p s = case parse pSexp "" s of
                      Left _ -> []
                      Right e -> [(e,"")]

---------------------------------------------------------------------------
-- Sexp Pretty Printer                                                   --
---------------------------------------------------------------------------

showSexp' :: Sexp -> ShowS
showSexp' Snil = showString "()"
showSexp' (Snum n) = showsPrec 0 n
showSexp' (Ssym s) = showString s
showSexp' (Scons e1 e2) = showHead (Scons e1 e2) . showString ")"
    where
      showHead (Scons Snil e2') = showString "(" . showSexp' e2'
      showHead (Scons e1' e2') = showHead e1' . showString " " . showSexp' e2'
      showHead e = showString "(" . showSexp' e . showString " ."

-- On peut utiliser notre pretty-printer pour la fonction générique "show"
-- (utilisée par la boucle interactive de Hugs).  Mais avant de faire cela,
-- il faut enlever le "deriving Show" dans la déclaration de Sexp.
{-
instance Show Sexp where
    showsPrec p = showSexp'
-}

-- Pour lire et imprimer des Sexp plus facilement dans la boucle interactive
-- de Hugs:
readSexp :: String -> Sexp
readSexp = read
showSexp :: Sexp -> String
showSexp e = showSexp' e ""

---------------------------------------------------------------------------
-- Représentation intermédiaire L(ambda)exp(ression)                     --
---------------------------------------------------------------------------

type Var = String
type Tag = String
type Pat = (Tag, [Var])
data BindingType = Lexical | Dynamic
                   deriving (Show, Eq)
    
data Lexp = Lnum Int            -- Constante entière.DONE
          | Lvar Var            -- Référence à une variable.DONE
          | Llambda [Var] Lexp  -- Fonction anonyme prenant un argument.DONE 
          | Lapp Lexp [Lexp]    -- Appel de fonction, avec un argument.DONE
          | Lcons Tag [Lexp]    -- Constructeur de liste vide.DONE
          | Lcase Lexp [(Pat, Lexp)] -- Expression conditionelle.done ??
          | Llet BindingType Var Lexp Lexp -- Déclaration de variable locale
          deriving (Show, Eq)







parseArgs :: Sexp -> [Var] -- signature de type de parseArgs
parseArgs Snil = []
parseArgs (Scons inside (Ssym varname)) = 
 let liste = (parseArgs inside) 
 in liste ++ [varname]
parseArgs _ = error "erreur dans les arguments d’une fonction"

--Pour le Lcase:
parseCases::Sexp-> [(Pat,Lexp)]
parseCases (Scons (Scons Snil (Ssym "_")) expr) = [(("_", []), (s2l expr))]
parseCases (Scons (Scons Snil (Scons Snil (Ssym nom))) expr) = [((nom, []), (s2l expr))]
parseCases (Scons (Scons Snil (Scons x (Ssym y))) expr) = 
    case parseCases (Scons (Scons Snil x) expr) of
        [((nom,liste),exprI)] -> [((nom,(liste ++ [y])),exprI)]
        _ -> error "pattern can't contain value"

rechercheNom:: Sexp -> String
rechercheNom (Scons Snil (Ssym nom)) = nom
rechercheNom (Scons interieur _) = rechercheNom interieur

rechercheArg::Sexp -> Sexp
rechercheArg (Scons Snil (Ssym nom)) = Snil
rechercheArg (Scons autre (Ssym nom)) = Scons (rechercheArg autre) (Ssym nom)

simplifie:: Sexp -> Sexp
simplifie Snil = Snil
simplifie (Scons interne (Scons (Scons Snil (Ssym nom)) expr))=
    (Scons (simplifie interne) (Scons (Scons Snil (Ssym nom)) expr))
simplifie (Scons interne (Scons (Scons Snil autre) expr)) =
    (Scons (simplifie interne) (Scons (Scons Snil (Ssym (rechercheNom autre))) (Scons(Scons(Scons Snil (Ssym "lambda")) (rechercheArg autre)) expr)))


-- Première passe simple qui analyse un Sexp et construit une Lexp équivalente.
s2l :: Sexp -> Lexp
s2l (Snum n) = Lnum n
s2l (Ssym s) = Lvar s

s2l (Scons (Scons (Scons Snil (Ssym "dlet")) aff) exp) = 
 case (simplifie aff) of
  (Scons Snil (Scons (Scons Snil (Ssym nom)) expr2)) -> 
   Llet Dynamic nom (s2l expr2) (s2l exp)
  (Scons interieur (Scons (Scons Snil (Ssym nom)) expr2)) ->
    case (s2l (Scons (Scons (Scons Snil (Ssym "dlet")) interieur) exp)) of
     Llet Dynamic a b c -> Llet Dynamic a b (Llet Dynamic nom (s2l expr2) c)

s2l (Scons (Scons (Scons Snil (Ssym "slet")) aff) exp) = 
 case (simplifie aff) of
  (Scons Snil (Scons (Scons Snil (Ssym nom)) expr2)) -> 
   Llet Lexical nom (s2l expr2) (s2l exp)
  (Scons interieur (Scons (Scons Snil (Ssym nom)) expr2)) ->
    case (s2l (Scons (Scons (Scons Snil (Ssym "slet")) interieur) exp)) of
     Llet Lexical a b c -> Llet Dynamic a b (Llet Lexical nom (s2l expr2) c)

--Pour Lcons:
s2l (Scons (Scons Snil (Ssym "cons")) (Ssym tag)) = Lcons tag []


--Pour le Llambda:
s2l (Scons(Scons(Scons Snil (Ssym "lambda")) listeArg) body) = 
    let args' = parseArgs listeArg
    in Llambda (args') (s2l body)

--Pour le if :
s2l (Scons (Scons (Scons (Scons Snil (Ssym "if")) condi) siV) siF) =
    Lcase (s2l condi) [(("true",[]), (s2l siV)),(("false",[]), (s2l siF))]

--Pour le case:
s2l (Scons (Scons Snil (Ssym "case")) x) = Lcase (s2l x) []

			
--Pour le Lapp:
s2l (Scons Snil x) = Lapp (s2l x) []

s2l (Scons x y) = 
    case (s2l x) of 
        Lcons tag liste -> Lcons tag (liste ++ [(s2l y)])
        Lcase ele liste -> Lcase ele (liste ++ (parseCases y))
        Lapp expr liste -> Lapp expr (liste ++ [(s2l y)])
		
s2l se = error ("Malformed Sexp: " ++ (showSexp se))

---------------------------------------------------------------------------
-- Représentation du contexte d'exécution                                --
---------------------------------------------------------------------------

type Arity = Int

-- Type des valeurs manipulée à l'exécution.
data Value = Vnum Int
           | Vcons Tag [Value]
           | Vfun Arity (Env -> [Value] -> Value)

instance Show Value where
    showsPrec p (Vnum n) = showsPrec p n
    showsPrec p (Vcons tag vs) =
        let showTail [] = showChar ']'
            showTail (v : vs') =
                showChar ' ' . showsPrec p v . showTail vs'
        in showChar '[' . showString tag . showTail vs
    showsPrec _ (Vfun arity _)
        = showString ("<" ++ show arity ++ "-args-function>")

type Env = [(Var, Value)]

-- L'environnement initial qui contient les fonctions prédéfinies.
env0 :: Env
env0 = let false = Vcons "false" []
           true = Vcons "true" []
           mkbop (name, op) =
               (name, Vfun 2 (\ _ [Vnum x, Vnum y] -> Vnum (x `op` y)))
           mkcmp (name, op) =
               (name, Vfun 2 (\ _ [Vnum x, Vnum y]
                                  -> if x `op` y then true else false))
       in [("false", false),
           ("true", true)]
          ++ map mkbop
              [("+", (+)),
               ("*", (*)),
               ("/", div),
               ("-", (-))]
          ++ map mkcmp
              [("<=", (<=)),
               ("<", (<)),
               (">=", (>=)),
               (">", (>)),
               ("=", (==))]

---------------------------------------------------------------------------
-- Évaluateur                                                            --
---------------------------------------------------------------------------

lookupenv :: Env -> Var -> Value
lookupenv [] _ = error "env empty"
lookupenv ((t,v):xs) i = if (t==i) then v else (lookupenv xs i)

joinVarVal:: [Var] -> [Value] -> Env
joinVarVal _ [] = []
joinVarVal (x:xs) (y:ys) = [(x,y)] ++ (joinVarVal xs ys)


eval :: Env -> Env -> Lexp -> Value
eval _senv _denv (Lnum n) = Vnum n
eval _senv _denv (Lvar x) = lookupenv (_senv ++ _denv) x
eval _senv _denv (Lcons e1 e2)=
    let e2' = map (eval _senv _denv) e2
    in Vcons e1 e2'
eval _senv _denv (Llambda x body)=
    Vfun (length x) (\env liste -> eval ((joinVarVal x liste) ++ _senv) env body)

eval _senv _denv (Lcase ele (((tag,liste), body):rest)) =
 case (eval _senv _denv ele) of
    Vcons tag' liste2 -> 
     if (tag == "_" || tag == tag') 
     then eval _senv ((joinVarVal liste liste2) ++ _denv) body 
     else eval _senv _denv (Lcase ele rest)
    _ -> error "case does not exist"


eval _senv _denv (Lapp e1 e2) =
 let e1' = eval _senv _denv e1
     e2' = map(eval _senv _denv) e2
 in case (e1') of
    Vfun n body -> if (n == (length e2)) then body _denv e2' else error "mauvais arg"
    v -> error ("Ce n'est pas une fonction: " ++ show v)


eval _senv _denv (Llet bindt x e1 e2) = 
 case bindt of
  Lexical -> eval ((x, (eval _senv _denv e1)):_senv) _denv e2
  Dynamic -> eval _senv ((x, (eval _senv _denv e1)):_denv) e2


eval _ _ e = error ("Can't eval: " ++ show e)


---------------------------------------------------------------------------
-- Toplevel                                                              --
---------------------------------------------------------------------------
	

evalSexp :: Sexp -> Value
evalSexp = eval env0 [] . s2l



-- Lit un fichier contenant plusieurs Sexps, les évalues l'une après
-- l'autre, et renvoie la liste des valeurs obtenues.
run :: FilePath -> IO ()
run filename =
    do s <- readFile filename
       (hPutStr stdout . show)
           (let sexps s' = case parse pSexps filename s' of
                             Left _ -> [Ssym "#<parse-error>"]
                             Right es -> es
            in map evalSexp (sexps s))



