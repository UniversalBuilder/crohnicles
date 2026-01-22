class FoodItem {
  final String name;
  final String category;
  final String subCategory;

  const FoodItem(this.name, this.category, this.subCategory);

  @override
  String toString() => name;
}

const List<FoodItem> foodDatabase = [
  // Féculents / Céréales
  FoodItem("Pâtes aux oeufs", "Féculent", "Blé"),
  FoodItem("Pâtes sans gluten", "Féculent", "Maïs/Riz"),
  FoodItem("Riz blanc", "Féculent", "Riz"),
  FoodItem("Riz complet", "Féculent", "Riz"),
  FoodItem("Pain blanc", "Féculent", "Blé"),
  FoodItem("Pain complet", "Féculent", "Blé"),
  FoodItem("Pomme de terre vapeur", "Féculent", "Tubercule"),
  FoodItem("Frites", "Gras", "Tubercule"),
  FoodItem("Quinoa", "Féculent", "Graine"), // Pseudo-céréale

  // Protéines
  FoodItem("Poulet rôti", "Protéine", "Volaille"),
  FoodItem("Steak haché", "Protéine", "Boeuf"),
  FoodItem("Saumon cuit", "Protéine", "Poisson"),
  FoodItem("Oeuf dur", "Protéine", "Oeuf"),
  FoodItem("Oeuf au plat", "Gras", "Oeuf"),
  FoodItem("Tofu", "Protéine", "Soja"),
  FoodItem("Lentilles", "Légumineuse", "Légumineuse"),
  FoodItem("Haricots rouges", "Légumineuse", "Haricot"),

  // Légumes
  FoodItem("Carottes cuites", "Légume", "Racine"),
  FoodItem("Carottes rapées", "Légume", "Racine"),
  FoodItem("Haricots verts", "Légume", "Vert"),
  FoodItem("Brocoli", "Légume", "Crucifère"),
  FoodItem("Courgette", "Légume", "Courge"),
  FoodItem("Tomate", "Légume", "Solanacée"),

  // Fruits
  FoodItem("Banane", "Fruit", "Fruit"),
  FoodItem("Pomme", "Fruit", "Fruit"),
  FoodItem("Compote de pomme", "Fruit", "Cuit"),
  FoodItem("Orange", "Fruit", "Agrume"),

  // Produits Laitiers & Alternatives
  FoodItem("Yaourt nature", "Laitage", "Lactose"),
  FoodItem("Fromage blanc", "Laitage", "Lactose"),
  FoodItem("Comté", "Laitage", "Fromage dur"),
  FoodItem("Lait d'amande", "Substitut", "Végétal"),
  
  // Plats complets / Divers
  FoodItem("Pizza", "Fast-food", "Mixte"),
  FoodItem("Burger", "Fast-food", "Mixte"),
  FoodItem("Salade César", "Salade", "Mixte"),
  FoodItem("Chocolat noir", "Sucre", "Cacao"),
  FoodItem("Café", "Boisson", "Excitant"),
];
